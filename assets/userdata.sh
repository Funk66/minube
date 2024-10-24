#!/bin/bash

set -eux -o pipefail

export DEBIAN_FRONTEND=noninteractive

mkdir -p /etc/apt/keyrings/
wget -q -O - https://apt.grafana.com/gpg.key | gpg --dearmor | tee /etc/apt/keyrings/grafana.gpg > /dev/null
echo "deb [signed-by=/etc/apt/keyrings/grafana.gpg] https://apt.grafana.com stable main" | tee /etc/apt/sources.list.d/grafana.list

apt update
apt upgrade -y
apt install -y unzip sqlite3 debian-keyring debian-archive-keyring apt-transport-https nginx libnginx-mod-stream python3-certbot-dns-route53 alloy fail2ban
hostnamectl set-hostname minube

fallocate -l 1G /swap
chmod 600 /swap
mkswap /swap
swapon /swap
echo '/swap none swap sw 0 0' >> /etc/fstab
echo 'vm.swappiness=10' >> /etc/sysctl.conf

curl "https://awscli.amazonaws.com/awscli-exe-linux-aarch64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
./aws/install
rm -r aws awscliv2.zip

aws configure set default.s3.use_dualstack_endpoint true

TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
IPV4=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/public-ipv4)
INET=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/local-ipv4)
INET6=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/ipv6)

mkdir /etc/pihole
aws s3 cp s3://minube-backups/pihole-FTL.db.gz - | gunzip > /etc/pihole/pihole-FTL.db
cat << EOF > /etc/pihole/setupVars.conf
WEBPASSWORD=
PIHOLE_INTERFACE=wg0
IPV4_ADDRESS=$INET/26
IPV6_ADDRESS=$INET6/64
QUERY_LOGGING=true
INSTALL_WEB=true
DNSMASQ_LISTENING=local
PIHOLE_DNS_1=193.110.81.9
PIHOLE_DNS_2=185.253.5.9
DNS_FQDN_REQUIRED=true
DNS_BOGUS_PRIV=true
DNSSEC=true
TEMPERATUREUNIT=C
WEBUIBOXEDLAYOUT=traditional
API_QUERY_LOG_SHOW=all
API_PRIVACY_MODE=false
EOF
echo MAXDBDAYS=1425 > /etc/pihole/pihole-FTL.conf
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
chmod +x /etc/pihole/backup
ln -s /etc/pihole/backup /etc/cron.daily/backup
for SERVICE in backup wg-quick@casa alloy fail2ban fail2ban_exporter; do
	systemctl enable "$SERVICE"
done

HOSTED_ZONE=$(aws route53 list-hosted-zones-by-name --dns-name guirao.net | jq -r '.HostedZones[0].Id')
for SUBDOMAIN in minube mail calendar; do
  aws route53 change-resource-record-sets --hosted-zone-id "$HOSTED_ZONE" --change-batch '{"Changes":[{"Action":"UPSERT","ResourceRecordSet":{"Name":"'"$SUBDOMAIN"'.guirao.net.","Type":"A","TTL":300,"ResourceRecords":[{"Value":"'"$IPV4"'"}]}}]}'
  aws route53 change-resource-record-sets --hosted-zone-id "$HOSTED_ZONE" --change-batch '{"Changes":[{"Action":"UPSERT","ResourceRecordSet":{"Name":"'"$SUBDOMAIN"'.guirao.net.","Type":"AAAA","TTL":300,"ResourceRecords":[{"Value":"'"$INET6"'"}]}}]}'
done

sed -i 's|80|8053|' /etc/lighttpd/lighttpd.conf

echo "certbot certonly --dns-route53 -m postmaster@guirao.net -d minube.guirao.net,mail.guirao.net,photos.guirao.net,calendar.guirao.net --agree-tos --non-interactive" > /etc/cron.weekly/certbot
chmod +x /etc/cron.weekly/certbot
/etc/cron.weekly/certbot

curl -L https://gitlab.com/hectorjsmith/fail2ban-prometheus-exporter/-/releases/v0.10.1/downloads/fail2ban_exporter_0.10.1_linux_arm64.tar.gz | tar --wildcards -xz -C /usr/bin 'fail2ban_exporter'

reboot now
