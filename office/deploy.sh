#!/usr/bin/env bash
#
# Deploy office configuration to the remote server via rsync.
# Usage: deploy.sh
#
# Maps the local directory structure to the user's home directory:
#   office/config/ -> ~/.config/
#   office/local/  -> ~/.local/
#
# After syncing, it detects what changed and reloads/restarts the
# appropriate systemd services.

set -euo pipefail

HOST="pi@office"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

RSYNC_OPTS=(
  --recursive
  --perms
  --times
  --compress
  --itemize-changes
  --exclude="deploy.sh"
)

echo "Syncing config/ -> ~/.config/"
CONFIG_CHANGES=$(rsync "${RSYNC_OPTS[@]}" "$SCRIPT_DIR/config/" "$HOST:.config/")

echo "Syncing local/ -> ~/.local/"
LOCAL_CHANGES=$(rsync "${RSYNC_OPTS[@]}" "$SCRIPT_DIR/local/" "$HOST:.local/")

if [[ -z "$CONFIG_CHANGES" && -z "$LOCAL_CHANGES" ]]; then
  echo "Nothing changed."
  exit 0
fi

echo ""
echo "Changed files:"
echo "$CONFIG_CHANGES"
echo "$LOCAL_CHANGES"

NEEDS_DAEMON_RELOAD=false
RESTART_SERVICES=()

while IFS= read -r line; do
  [[ -z "$line" ]] && continue
  # rsync itemize format: >f..t...... path/to/file
  file="${line#* }"

  case "$file" in
  containers/systemd/*)
    NEEDS_DAEMON_RELOAD=true
    # Extract pod/service name from path: containers/systemd/<name>/...
    RESTART_SERVICES+=("$(echo "$file" | cut -d/ -f3)")
    ;;
  systemd/user/*)
    NEEDS_DAEMON_RELOAD=true
    ;;
  esac
done <<<"$CONFIG_CHANGES"

# A script mounted into a long-running container is only read when the container
# starts, so changing it has to restart the service that mounts it.
while IFS= read -r line; do
  [[ -z "$line" ]] && continue
  file="${line#* }"
  case "$file" in
  bin/*.sh)
    name=$(basename "$file" .sh)
    if [[ -d "$SCRIPT_DIR/config/containers/systemd/$name" ]]; then
      RESTART_SERVICES+=("$name")
    fi
    ;;
  esac
done <<<"$LOCAL_CHANGES"

if [[ "$NEEDS_DAEMON_RELOAD" == true ]]; then
  echo ""
  echo "Reloading systemd daemon..."
  ssh "$HOST" "systemctl --user daemon-reload"
fi

# Deduplicate and restart affected services
if [[ ${#RESTART_SERVICES[@]} -gt 0 ]]; then
  mapfile -t UNIQUE_SERVICES < <(printf '%s\n' "${RESTART_SERVICES[@]}" | sort -u)
  for service in "${UNIQUE_SERVICES[@]}"; do
    echo "Restarting $service..."
    # Services made of a single container have no <name>-pod.service.
    # shellcheck disable=SC2029  # intentional client-side expansion
    ssh "$HOST" "systemctl --user restart ${service}-pod.service 2>/dev/null || systemctl --user restart ${service}.service"
  done
fi

echo ""
echo "Done."