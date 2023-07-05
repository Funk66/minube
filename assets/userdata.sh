#!/bin/bash

apt update
apt upgrade -y
apt install -y awscli
hostnamectl set-hostname minube

INET=$(curl http://169.254.169.254/latest/meta-data/local-ipv4)
mkdir /etc/pihole
cat << EOF > /etc/pihole/setupVars.conf
WEBPASSWORD=
PIHOLE_INTERFACE=wg0
IPV4_ADDRESS=$INET/24
QUERY_LOGGING=true
INSTALL_WEB=true
DNSMASQ_LISTENING=local
PIHOLE_DNS_1=1.1.1.1
PIHOLE_DNS_2=8.8.8.8
DNS_FQDN_REQUIRED=true
DNS_BOGUS_PRIV=true
DNSSEC=true
TEMPERATUREUNIT=C
WEBUIBOXEDLAYOUT=traditional
API_QUERY_LOG_SHOW=all
API_PRIVACY_MODE=false
EOF
git clone --depth 1 https://github.com/pi-hole/pi-hole.git /tmp/pi-hole
/tmp/pi-hole/automated\ install/basic-install.sh --unattended
aws s3 cp s3://minube-backups/etc/hosts /etc/hosts
aws s3 cp s3://minube-backups/etc/pihole/pihole-FTL.db /etc/pihole/pihole-FTL.db
echo "https://blocklistproject.github.io/Lists/everything.txt" >> /etc/pihole/adlists.list

cat << EOF > /tmp/pivpn.conf
IPv4dev=ens5
install_user=ubuntu
install_home=/home/ubuntu
VPN=wireguard
pivpnNET="10.10.10.0/24"
subnetClass=24
ALLOWED_IPS="10.10.10.0/24"
pivpnMTU=1420
pivpnPORT=51820
pivpnDNS1=$INET
pivpnHOST=minube.guirao.com
pivpnPERSISTENTKEEPALIVE=25
UNATTUPG=1
EOF

git clone https://github.com/pivpn/pivpn /tmp/pivpn
cd /tmp/ || exit
bash pivpn/auto_install/install.sh --unattended /tmp/pivpn.conf
aws s3 cp s3://minube-backups/etc/wireguard.tgz - | tar -C /etc/wireguard -xzf -

reboot now
