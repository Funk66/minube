#!/bin/bash

set -eux -o pipefail

aws() {
	podman run --rm -v /:/host docker.io/amazon/aws-cli "$@"
}

export DEBIAN_FRONTEND=noninteractive

hostnamectl set-hostname minube
echo "127.0.0.1 minube" >>/etc/hosts
sed -i 's/preserve_hostname: false/preserve_hostname: true/' /etc/cloud/cloud.cfg

snap remove amazon-ssm-agent

apt update
apt upgrade -y
apt install -y podman

timedatectl set-timezone Europe/Berlin

fallocate -l 4G /swap
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

aws s3 cp --recursive s3://minube-fs/ /host/

mkdir /data
chown ubuntu:ubuntu /data
echo 'UUID="96786644-b31e-4923-bccd-c80f2c3e7c0f" /data xfs defaults,nofail' >>/etc/fstab
systemctl daemon-reload
mount -a
echo 'set -o vi' >>/etc/profile

systemctl enable {podman-auto-update,immich-backup,stalwart-backup,paperless-backup}.timer

reboot now
