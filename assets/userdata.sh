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
apt install -y podman systemd-container

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

useradd --uid 2000 --create-home --shell /sbin/nologin podman
loginctl enable-linger podman
aws s3 cp --recursive s3://minube-files/etc/ /etc/
aws s3 cp --recursive s3://minube-files/opt/ /opt/
aws s3 cp --recursive s3://minube-files/podman/ /host/home/podman/.config/containers/systemd/
aws s3 cp --recursive s3://minube-files/systemd/ /host/home/podman/.config/systemd/user/
chown -R podman:podman /home/podman/.config
usermod -g podman ubuntu

mkdir /data
echo 'UUID="96786644-b31e-4923-bccd-c80f2c3e7c0f" /data xfs defaults,nofail' >>/etc/fstab
systemctl daemon-reload
mount -a

systemctl enable --now {podman-auto-update,sshfp.service}.timer
sudo -u podman XDG_RUNTIME_DIR=/run/user/2000 systemctl --user enable --now {immich-backup,dawarich-backup}.timer

echo "SystemMaxUse=1G" >>/etc/systemd/journald.conf

shutdown -r +1
