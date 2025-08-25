#!/bin/bash

set -eux -o pipefail

aws() {
	if [[ "$1" == "-v" ]]; then
		podman run --rm -v "$2" docker.io/amazon/aws-cli "${@:3}"
	else
		podman run --rm docker.io/amazon/aws-cli "$@"
	fi
}

export DEBIAN_FRONTEND=noninteractive

apt update
apt upgrade -y
apt install -y podman

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
aws route53 change-resource-record-sets --hosted-zone-id "$HOSTED_ZONE" --change-batch '{"Changes":[{"Action":"UPSERT","ResourceRecordSet":{"Name":"test.guirao.net.","Type":"A","TTL":300,"ResourceRecords":[{"Value":"'"$INET"'"}]}}]}'
aws route53 change-resource-record-sets --hosted-zone-id "$HOSTED_ZONE" --change-batch '{"Changes":[{"Action":"UPSERT","ResourceRecordSet":{"Name":"test.guirao.net.","Type":"AAAA","TTL":300,"ResourceRecords":[{"Value":"'"$INET6"'"}]}}]}'

sed -r -i 's/#?DNSStubListener=yes/DNSStubListener=no/g' /etc/systemd/resolved.conf
rm /etc/resolv.conf
ln -s /run/systemd/resolve/resolv.conf /etc/resolv.conf
systemctl restart systemd-resolved
loginctl enable-linger ubuntu
# TODO: create for user?
# mkdir -p ~/.config/containers/systemd/
systemctl --user enable podman-auto-update.service # run as user

aws -v /:/host s3 sync s3://minube-fs/ /host/

# TODO: enable minube-network pihole wireguard?
# TODO: copy quadlets and .env from S3

echo 'UUID="bb61a946-053e-432e-96bc-02d07c30a820" /data xfs defaults,nofail' >>/etc/fstab
#mount -a
echo 'set -o vi' >>/etc/profile

reboot now
