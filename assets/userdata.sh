#!/bin/bash

apt update
apt upgrade -y
apt install -y awscli

cat << EOF > /tmp/pivpn.conf
IPv4dev=ens5
install_user=ubuntu
install_home=/home/ubuntu
VPN=wireguard
pivpnNET=10.0.0.0
subnetClass=24
ALLOWED_IPS="10.0.0.0/28"
pivpnMTU=1420
pivpnPORT=51820
pivpnDNS1=169.254.169.253
pivpnDNS2=1.1.1.1
pivpnHOST=minube.guirao.com
pivpnPERSISTENTKEEPALIVE=25
UNATTUPG=1
EOF

git clone https://github.com/pivpn/pivpn /tmp/pivpn
cd /tmp/ || exit
bash pivpn/auto_install/install.sh --unattended /tmp/pivpn.conf
aws s3 cp s3://minube-backups/pivpn.tgz - | tar -C /etc/wireguard -xzf -

reboot now
