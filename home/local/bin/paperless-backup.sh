#!/usr/bin/bash

set -euo pipefail

EXPORT_DIR="$HOME/.local/state/paperless/export"

podman exec paperless document_exporter ../export \
  --no-archive --no-thumbnail --delete --no-progress-bar

file_count=$(find "$EXPORT_DIR" -type f | wc -l)
if [[ "$file_count" -lt 1 ]]; then
  echo "ERROR: Export directory is empty, aborting S3 sync" >&2
  exit 1
fi

podman run --rm \
  -v "$EXPORT_DIR":/paperless \
  --env-file ~/.config/aws/credentials \
  -i docker.io/amazon/aws-cli \
  s3 sync /paperless "s3://minube-docs/" \
  --storage-class STANDARD_IA \
  --no-progress \
  --delete
