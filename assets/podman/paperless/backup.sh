#!/usr/bin/bash

set -e

podman exec paperless document_exporter ../export --no-archive --no-thumbnail --delete --no-progress-bar
podman run --rm -v /data/paperless/paperless/export:/paperless -i docker.io/amazon/aws-cli s3 sync /paperless "s3://minube-docs/" --storage-class DEEP_ARCHIVE --no-progress --delete
