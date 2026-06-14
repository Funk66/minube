#!/bin/bash

set -Eeuo pipefail

BUCKET=minube-backups
PREFIX=stalwart
DATA_DIR=/data/stalwart
NOTIFY=/opt/scripts/send-notification.sh
MIN_SIZE=10000000
SHRINK_THRESHOLD=70 # alert when the new snapshot is <70% the size of the previous one

exec 200>/tmp/stalwart-backup.lock
flock -n 200 || {
  echo "Another backup is already running"
  exit 0
}

aws() {
  podman run --rm -i --network host docker.io/amazon/aws-cli \
    --region eu-central-1 "$@"
}

alert() {
  "$NOTIFY" "[$(hostname)] Stalwart backup: $1" "$2" || true
}

snapshot=$(mktemp "$DATA_DIR/snapshot-XXXXXX.tar.gz")

finish() {
  rm -f "$snapshot"
  if ! systemctl --user is-active --quiet stalwart; then
    systemctl --user start stalwart || true
    sleep 5
    if ! systemctl --user is-active --quiet stalwart; then
      alert "CRITICAL - Stalwart is down" \
        "Stalwart could not be restarted after the backup. Manual intervention required."
      exit 1
    fi
  fi
}
trap finish EXIT

previous=$(aws s3 ls "s3://${BUCKET}/${PREFIX}/" | awk '/\.tar\.gz$/ {size=$3} END {print size}')

systemctl --user stop stalwart
tar -cz -C "$DATA_DIR" data >"$snapshot"
systemctl --user start stalwart

size=$(stat -c%s "$snapshot")
if ((size < MIN_SIZE)); then
  alert "Snapshot too small, not uploaded" \
    "Today's snapshot is only ${size} bytes; the database at ${DATA_DIR}/data is probably missing or empty. Nothing was uploaded."
  exit 1
fi

if [[ -n "$previous" ]] && ((size * 100 < previous * SHRINK_THRESHOLD)); then
  alert "Backup shrunk" \
    "Today's snapshot is ${size} bytes, while the previous backup was ${previous} bytes. Uploading it anyway, but the database may have lost data."
fi

key="${PREFIX}/$(date +%F).tar.gz"
aws s3 cp --no-progress --storage-class STANDARD_IA - "s3://${BUCKET}/${key}" <"$snapshot"

uploaded=$(aws s3api head-object --bucket "$BUCKET" --key "$key" --query ContentLength --output text)
if [[ "$uploaded" != "$size" ]]; then
  alert "Upload size mismatch" \
    "The uploaded object ${key} is ${uploaded} bytes, but the local snapshot is ${size} bytes. The backup is likely corrupt."
  exit 1
fi
