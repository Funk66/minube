#!/bin/bash

set -eo pipefail

. /data/stalwart/env
export PGPASSWORD="$POSTGRES_PASSWORD"
PIPE=$(mktemp -u)
mkfifo "$PIPE"
trap 'rm -f "$PIPE"' EXIT
podman run --rm -i docker.io/amazon/aws-cli s3 cp - "s3://minube-backups/stalwart/$(date +%Y%m%d).sql" --storage-class STANDARD_IA --no-progress <"$PIPE" &
podman exec postgres pg_dump -U "stalwart" >"$PIPE"
wait
