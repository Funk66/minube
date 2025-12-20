#!/usr/bin/bash

set -euo pipefail

exec 200>"/tmp/immich-s3-backup.lock"
flock -n 200 || {
	log "Another backup is already running"
	exit 0
}

aws_sync() {
	podman run --rm -i \
		-v "/data/immich/data:/immich:ro" \
		"docker.io/amazon/aws-cli" \
		s3 sync \
		--no-progress \
		--only-show-errors \
		--delete \
		--exclude ".immich" \
		"$@"
}

aws_sync --storage-class DEEP_ARCHIVE "/immich/library" "s3://minube-photos/library/"
aws_sync --storage-class STANDARD_IA "/immich/backups" "s3://minube-backups/immich/"
