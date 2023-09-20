#!/bin/bash

set -x

export DEBIAN_FRONTEND=noninteractive

echo "iface eth0 inet6 dhcp" >> /etc/network/interfaces.d/60-default-with-ipv6.cfg
dhclient -6

apt update
apt upgrade -y
apt install -y awscli
hostnamectl set-hostname minube

aws configure set default.s3.use_dualstack_endpoint true

INET=$(curl http://169.254.169.254/latest/meta-data/local-ipv4)
INET6=$(curl http://169.254.169.254/latest/meta-data/ipv6)
mkdir /etc/pihole
cat << EOF > /etc/pihole/setupVars.conf
WEBPASSWORD=
PIHOLE_INTERFACE=wg0
IPV4_ADDRESS=$INET/26
IPV6_ADDRESS=$INET6/64
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
git clone --quiet --depth 1 https://github.com/pi-hole/pi-hole.git /tmp/pi-hole
/tmp/pi-hole/automated\ install/basic-install.sh --unattended
echo "https://blocklistproject.github.io/Lists/everything.txt" >> /etc/pihole/adlists.list

cat << EOF > /tmp/pivpn.conf
IPv4dev=ens5
IPv6dev=ens5
install_user=ubuntu
install_home=/home/ubuntu
VPN=wireguard
pivpnNET="10.10.10.0"
subnetClass=26
pivpnNETv6="fd11:5ee:bad:c0de::"
subnetClassv6=64
pivpnforceipv6route=1
pivpnforceipv6=0
pivpnenableipv6=1
ALLOWED_IPS="10.10.10.0/26, fd11:5ee:bad:c0de::/64"
pivpnMTU=1420
pivpnPORT=51820
pivpnDNS1=10.10.10.1
pivpnHOST=minube.guirao.net
pivpnPERSISTENTKEEPALIVE=25
UNATTUPG=1
EOF

git clone --quiet --depth 1 https://github.com/pivpn/pivpn /usr/local/src/pivpn
bash /usr/local/src/pivpn/auto_install/install.sh --unattended /tmp/pivpn.conf
aws s3 cp --recursive s3://minube-backups/etc/ /etc/

reboot now
