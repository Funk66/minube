#!/bin/bash

set -eo pipefail

. /data/stalwart/env
export PGPASSWORD="$POSTGRES_PASSWORD"
podman exec postgres pg_dump -U "stalwart" | podman run --rm -i docker.io/amazon/aws-cli s3 cp - "s3://minube-backups/stalwart/$(date +%Y%m%d).sql" --storage-class STANDARD_IA --no-progress
