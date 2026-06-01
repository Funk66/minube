#!/bin/bash

set -eux -o pipefail

export DEBIAN_FRONTEND=noninteractive

hostnamectl set-hostname minube
echo "127.0.0.1 minube" >>/etc/hosts
echo 'preserve_hostname: true' >/etc/cloud/cloud.cfg.d/99-preserve-hostname.cfg

snap remove amazon-ssm-agent

apt update
apt upgrade -y
apt install -y podman systemd-container

timedatectl set-timezone Europe/Berlin

fallocate -l 1G /swap
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
usermod -g podman ubuntu

mkdir /data
echo 'UUID="0f22c5e8-b1dc-48ed-97f1-8c454d55de20" /data ext4 defaults,nofail' >>/etc/fstab
systemctl daemon-reload
mount -a

systemctl enable --now podman-auto-update.timer
sudo -u podman XDG_RUNTIME_DIR=/run/user/2000 systemctl --user enable --now {immich-backup,dawarich-backup}.timer

echo "SystemMaxUse=1G" >>/etc/systemd/journald.conf

echo "find /data/stalwart/data -maxdepth 1 -name 'LOG.old.*' -mtime +7 -delete" >/etc/cron.daily/cleanup-stalwart-logs
echo "find /data/stalwart/logs -mtime +30 -delete" >/etc/cron.daily/cleanup-stalwart-logs

shutdown -r +1
