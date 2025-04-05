#!/bin/bash

set -eux -o pipefail

aws() {
	podman run --rm -v "/home:/home" -v "/etc:/etc" -e AWS_USE_DUALSTACK=true docker.io/amazon/aws-cli "$@"
}

export DEBIAN_FRONTEND=noninteractive

apt update
apt upgrade -y

install -m 0755 -d /etc/apt/keyrings

apt install -y podman

fallocate -l 2G /swap
chmod 600 /swap
mkswap /swap
swapon /swap
echo '/swap none swap sw 0 0' >>/etc/fstab
echo 'vm.swappiness=10' >>/etc/sysctl.conf

sed -r -i 's/#?DNSStubListener=yes/DNSStubListener=no/g' /etc/systemd/resolved.conf
rm /etc/resolv.conf
ln -s /run/systemd/resolve/resolv.conf /etc/resolv.conf
systemctl restart systemd-resolved
loginctl enable-linger ubuntu
mkdir -p ~/.config/containers/systemd/
systemctl --user enable podman-auto-update.service

TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
INET6=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/ipv6)

for SUBDOMAIN in minube mail calendar docs photos; do
	aws route53 change-resource-record-sets --hosted-zone-id "$HOSTED_ZONE" --change-batch '{"Changes":[{"Action":"UPSERT","ResourceRecordSet":{"Name":"'"$SUBDOMAIN"'.guirao.net.","Type":"AAAA","TTL":300,"ResourceRecords":[{"Value":"'"$INET6"'"}]}}]}'
done

echo 'UUID="bb61a946-053e-432e-96bc-02d07c30a820" /data xfs defaults,nofail' >>/etc/fstab
mount -a
echo 'set -o vi' >>/etc/profile

reboot now
