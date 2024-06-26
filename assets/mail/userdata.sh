#!/bin/bash

set -eux -o pipefail

export DEBIAN_FRONTEND=noninteractive

apt update
apt upgrade -y
apt install -y unzip
hostnamectl set-hostname mail

curl "https://awscli.amazonaws.com/awscli-exe-linux-aarch64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
./aws/install
rm -r aws awscliv2.zip

aws configure set default.s3.use_dualstack_endpoint true

TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
INET6=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/ipv6)

HOSTED_ZONE=$(aws route53 list-hosted-zones | jq -r '.HostedZones[] | select(.Name=="guirao.net.") | .Id')
aws route53 change-resource-record-sets --hosted-zone-id "$HOSTED_ZONE" --change-batch '{"Changes":[{"Action":"UPSERT","ResourceRecordSet":{"Name":"mail.guirao.net.","Type":"AAAA","TTL":300,"ResourceRecords":[{"Value":"'"$INET6"'"}]}}]}'

aws s3 cp --recursive s3://minube-backups/mail/opt/ /opt
curl --proto '=https' --tlsv1.2 -sSf https://get.stalw.art/install.sh | bash

aws s3 cp --recursive s3://minube-backups/mail/etc/ /etc
systemctl enable backup

# TODO: cronjob

reboot now
