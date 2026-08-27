#!/usr/bin/bash
#
# Dynamic DNS: keep this host's Route53 A/AAAA records pointing at its current
# public addresses.
#
# Runs inside the amazon/aws-cli container (see containers/systemd/dyndns),
# which already ships bash, curl, jq and aws. It loops forever instead of being
# timer-driven so that podman-auto-update can track the container and swap the
# image when a new aws-cli release is published.
#
# Route53 itself is the state store: every check compares the live record with
# the observed address, so there is nothing to persist locally and a container
# restart or a hand-edited record both settle on the next pass.
#
# Logging uses systemd priority prefixes, which only turn into real journal
# priorities because the quadlet sets LogDriver=passthrough:
#   debug (7)   every check
#   info (6)    a record was created, updated or removed
#   warning (4) an address lookup started failing, or recovered
#   error (3)   Route53 refused the change
# Lookup failures are logged once on the transition rather than on every pass,
# so an hour offline is one warning and one recovery, not six of each.

set -uo pipefail

DOMAIN="${DYNDNS_DOMAIN:?DYNDNS_DOMAIN is required}"
ZONE="${DYNDNS_ZONE:-${DOMAIN#*.}}"
INTERVAL="${DYNDNS_INTERVAL:-600}"
TTL="${DYNDNS_TTL:-300}"
# Consecutive failed IPv6 lookups before the AAAA record is withdrawn. A stale
# AAAA is worse than none: clients prefer IPv6 and only fall back after a stall.
AAAA_DELETE_AFTER="${DYNDNS_AAAA_DELETE_AFTER:-6}"

read -r -a IPV4_URLS <<<"${DYNDNS_IPV4_URLS:-https://checkip.amazonaws.com https://api.ipify.org https://icanhazip.com}"
read -r -a IPV6_URLS <<<"${DYNDNS_IPV6_URLS:-https://api6.ipify.org https://icanhazip.com}"

log() { printf '<%d>%s\n' "$1" "$2"; }
debug() { log 7 "$1"; }
info() { log 6 "$1"; }
warn() { log 4 "$1"; }
error() { log 3 "$1"; }

STDERR_FILE="${TMPDIR:-/tmp}/dyndns.err"
ZONE_ID=""
V4_FAILURES=0
V6_FAILURES=0

valid_ip() {
  case "$1" in
  -4) [[ $2 =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] ;;
  -6) [[ $2 =~ ^[0-9A-Fa-f:]{3,45}$ && $2 == *:*:* ]] ;;
  esac
}

# Query the echo services in order and return the first well-formed answer.
fetch_ip() {
  local family="$1" url address
  shift
  for url in "$@"; do
    address=$(curl "$family" --silent --show-error --fail --max-time 10 "$url" 2>/dev/null) || continue
    address="${address//[[:space:]]/}"
    if valid_ip "$family" "$address"; then
      printf '%s' "$address"
      return 0
    fi
    debug "Discarded malformed answer from ${url}"
  done
  return 1
}

resolve_zone_id() {
  local zones
  zones=$(aws route53 list-hosted-zones --output json) || return 1
  ZONE_ID=$(jq -r --arg name "${ZONE}." \
    'first(.HostedZones[] | select(.Name == $name) | .Id) // ""' <<<"$zones")
  ZONE_ID="${ZONE_ID##*/}"
  [[ -n $ZONE_ID ]]
}

# All record sets for our name, in one call: Route53 returns them contiguously
# starting at the requested name.
current_records() {
  aws route53 list-resource-record-sets \
    --hosted-zone-id "$ZONE_ID" \
    --start-record-name "${DOMAIN}." \
    --max-items 10 \
    --output json
}

record_value() {
  jq -r --arg name "${DOMAIN}." --arg type "$1" \
    'first(.ResourceRecordSets[] | select(.Name == $name and .Type == $type) | .ResourceRecords[0].Value) // ""' <<<"$2"
}

upsert_change() {
  jq -cn --arg name "${DOMAIN}." --arg type "$1" --arg value "$2" --argjson ttl "$TTL" \
    '{Action: "UPSERT", ResourceRecordSet: {Name: $name, Type: $type, TTL: $ttl, ResourceRecords: [{Value: $value}]}}'
}

delete_change() {
  jq -c --arg name "${DOMAIN}." --arg type "$1" \
    '{Action: "DELETE", ResourceRecordSet: first(.ResourceRecordSets[] | select(.Name == $name and .Type == $type))}' <<<"$2"
}

submit() {
  local batch output change
  batch=$(jq -cn --argjson changes "[$(printf '%s,' "$@" | sed 's/,$//')]" \
    '{Comment: "dyndns", Changes: $changes}') || return 1
  # Keep stderr out of $output: the CLI occasionally writes warnings there and
  # they would end up parsed as the response.
  if ! output=$(aws route53 change-resource-record-sets \
    --hosted-zone-id "$ZONE_ID" --change-batch "$batch" --output json 2>"$STDERR_FILE"); then
    error "Route53 rejected the change: $(tr '\n' ' ' <"$STDERR_FILE")"
    return 1
  fi
  change=$(jq -r '.ChangeInfo.Id' <<<"$output" 2>/dev/null)
  debug "Route53 change ${change:-unknown} submitted"
}

# One pass: look up both addresses, diff them against the live records, and push
# whatever differs. Never exits; a bad pass is logged and retried next interval.
check() {
  local address_v4="" address_v6="" records changes=()

  if [[ -z $ZONE_ID ]] && ! resolve_zone_id; then
    error "No hosted zone named ${ZONE} is visible to these credentials"
    return 1
  fi

  if address_v4=$(fetch_ip -4 "${IPV4_URLS[@]}"); then
    ((V4_FAILURES > 0)) && warn "IPv4 lookup recovered after ${V4_FAILURES} failures"
    V4_FAILURES=0
  else
    ((V4_FAILURES++))
    ((V4_FAILURES == 1)) && warn "IPv4 lookup failed; leaving the A record untouched"
    address_v4=""
  fi

  if address_v6=$(fetch_ip -6 "${IPV6_URLS[@]}"); then
    ((V6_FAILURES > 0)) && warn "IPv6 lookup recovered after ${V6_FAILURES} failures"
    V6_FAILURES=0
  else
    ((V6_FAILURES++))
    ((V6_FAILURES == 1)) && warn "IPv6 lookup failed; leaving the AAAA record untouched for now"
    address_v6=""
  fi

  records=$(current_records) || {
    error "Could not read the current records for ${DOMAIN}"
    return 1
  }

  local current_v4 current_v6
  current_v4=$(record_value A "$records")
  current_v6=$(record_value AAAA "$records")
  debug "public=${address_v4:--}/${address_v6:--} record=${current_v4:--}/${current_v6:--}"

  if [[ -n $address_v4 && $address_v4 != "$current_v4" ]]; then
    info "A ${DOMAIN}: ${current_v4:-<none>} -> ${address_v4}"
    changes+=("$(upsert_change A "$address_v4")")
  fi

  if [[ -n $address_v6 && $address_v6 != "$current_v6" ]]; then
    info "AAAA ${DOMAIN}: ${current_v6:-<none>} -> ${address_v6}"
    changes+=("$(upsert_change AAAA "$address_v6")")
  elif [[ -z $address_v6 && -n $current_v6 ]] && ((V6_FAILURES >= AAAA_DELETE_AFTER)); then
    info "AAAA ${DOMAIN}: withdrawing ${current_v6} after ${V6_FAILURES} failed lookups"
    changes+=("$(delete_change AAAA "$records")")
  fi

  ((${#changes[@]} == 0)) && return 0
  submit "${changes[@]}"
}

running=true
sleep_pid=""
stop() {
  running=false
  [[ -n $sleep_pid ]] && kill "$sleep_pid" 2>/dev/null
}
trap stop TERM INT

if [[ ${1:-} == --once ]]; then
  check
  exit $?
fi

info "Watching ${DOMAIN} every ${INTERVAL}s"
while $running; do
  check
  $running || break
  sleep "$INTERVAL" &
  sleep_pid=$!
  wait "$sleep_pid"
done
info "Stopped"
