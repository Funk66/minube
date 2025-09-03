#!/bin/bash

set -eux -o pipefail

aws() {
	podman run --rm -v /:/host docker.io/amazon/aws-cli "$@"
}

export DEBIAN_FRONTEND=noninteractive

apt update
apt upgrade -y
apt install -y podman

timedatectl set-timezone Europe/Berlin

fallocate -l 2G /swap
chmod 600 /swap
mkswap /swap
swapon /swap
echo '/swap none swap sw 0 0' >>/etc/fstab
echo 'vm.swappiness=10' >>/etc/sysctl.conf

TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
INET=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/public-ipv4)
INET6=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/ipv6)

HOSTED_ZONE=$(aws route53 list-hosted-zones-by-name --dns-name guirao.net | jq -r '.HostedZones[0].Id')
aws route53 change-resource-record-sets --hosted-zone-id "$HOSTED_ZONE" --change-batch '{"Changes":[{"Action":"UPSERT","ResourceRecordSet":{"Name":"minube.guirao.net.","Type":"A","TTL":300,"ResourceRecords":[{"Value":"'"$INET"'"}]}}]}'
aws route53 change-resource-record-sets --hosted-zone-id "$HOSTED_ZONE" --change-batch '{"Changes":[{"Action":"UPSERT","ResourceRecordSet":{"Name":"minube.guirao.net.","Type":"AAAA","TTL":300,"ResourceRecords":[{"Value":"'"$INET6"'"}]}}]}'

sed -r -i 's/#?DNSStubListener=yes/DNSStubListener=no/g' /etc/systemd/resolved.conf
rm /etc/resolv.conf
ln -s /run/systemd/resolve/resolv.conf /etc/resolv.conf
systemctl restart systemd-resolved
loginctl enable-linger ubuntu

aws s3 cp --recursive s3://minube-fs/ /host/

mkdir /data
chown ubuntu:ubuntu /data
echo 'UUID="96786644-b31e-4923-bccd-c80f2c3e7c0f" /data xfs defaults,nofail' >>/etc/fstab
systemctl daemon-reload
mount -a
echo 'set -o vi' >>/etc/profile

reboot now
