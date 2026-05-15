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
RESTART_PODS=()

while IFS= read -r line; do
  [[ -z "$line" ]] && continue
  # rsync itemize format: >f..t...... path/to/file
  file="${line#* }"

  case "$file" in
  containers/systemd/*)
    NEEDS_DAEMON_RELOAD=true
    # Extract pod/service name from path: containers/systemd/<name>/...
    pod=$(echo "$file" | cut -d/ -f3)
    RESTART_PODS+=("$pod")
    ;;
  systemd/user/*)
    NEEDS_DAEMON_RELOAD=true
    ;;
  esac
done <<<"$CONFIG_CHANGES"

if [[ "$NEEDS_DAEMON_RELOAD" == true ]]; then
  echo ""
  echo "Reloading systemd daemon..."
  ssh "$HOST" "systemctl --user daemon-reload"
fi

# Deduplicate and restart affected pods
if [[ ${#RESTART_PODS[@]} -gt 0 ]]; then
  mapfile -t UNIQUE_PODS < <(printf '%s\n' "${RESTART_PODS[@]}" | sort -u)
  for pod in "${UNIQUE_PODS[@]}"; do
    echo "Restarting $pod..."
    # shellcheck disable=SC2029  # intentional client-side expansion
    ssh "$HOST" "systemctl --user restart ${pod}-pod.service"
  done
fi

echo ""
echo "Done."