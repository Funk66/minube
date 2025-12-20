#!/bin/bash

set -Eeuo pipefail

trap 'systemctl --user start stalwart' EXIT

systemctl --user stop stalwart

tar -cz -C /data/stalwart data |
	podman run --rm -i docker.io/amazon/aws-cli \
		s3 cp --no-progress --storage-class STANDARD_IA - "s3://minube-backups/stalwart/$(date +%F).tar.gz"
