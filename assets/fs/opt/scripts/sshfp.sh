#!/bin/bash

set -euxo pipefail

HOSTED_ZONE=$(podman run --rm docker.io/amazon/aws-cli route53 list-hosted-zones-by-name --dns-name guirao.net | jq -r '.HostedZones[0].Id')
FINGERPRINTS=$(ssh-keygen -r "" | awk '/SSHFP/ {printf "{\"Value\": \"%s %s %s\"},", $3, $4, $5}' | sed 's/,$//')
podman run --rm docker.io/amazon/aws-cli route53 change-resource-record-sets --hosted-zone-id "$HOSTED_ZONE" --change-batch '{"Changes":[{"Action":"UPSERT","ResourceRecordSet":{"Name":"minube.guirao.net.","Type":"SSHFP","TTL":300,"ResourceRecords":['"$FINGERPRINTS"']}}]}'
