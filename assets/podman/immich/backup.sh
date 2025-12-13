#!/bin/bash

set -eo pipefail

sync() {
	podman run --rm -v /data/immich:/immich docker.io/amazon/aws-cli s3 sync --no-progress --delete --exclude ".immich" "$@"
}

sync --storage-class DEEP_ARCHIVE /immich/library s3://minube-photos/library
sync /immich/backups s3://minube-photos/backups
