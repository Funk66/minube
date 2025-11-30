#!/bin/bash

set -eo pipefail

# shellcheck source=/dev/null
. /data/dawarich/env
export PGPASSWORD="$POSTGRES_PASSWORD"
PIPE=$(mktemp -u)
mkfifo "$PIPE"
trap 'rm -f "$PIPE"' EXIT
podman run --rm -i docker.io/amazon/aws-cli s3 cp - "s3://minube-backups/dawarich/$(date +%Y%m%d).sql" --storage-class STANDARD_IA --no-progress <"$PIPE" &
podman exec postgis pg_dump -U "dawarich" >"$PIPE"
wait
