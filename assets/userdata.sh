#!/bin/bash

set -eux -o pipefail

export DEBIAN_FRONTEND=noninteractive

curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | tee /etc/apt/sources.list.d/caddy-stable.list

apt update
apt upgrade -y
apt install -y unzip sqlite3 debian-keyring debian-archive-keyring apt-transport-https caddy
hostnamectl set-hostname minube

curl "https://awscli.amazonaws.com/awscli-exe-linux-aarch64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
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
systemctl enable backup

HOSTED_ZONE=$(aws route53 list-hosted-zones | jq -r '.HostedZones[] | select(.Name=="guirao.net.") | .Id')
for SUBDOMAIN in minube photos calendar; do
  RECORDS=$(aws route53 list-resource-record-sets --hosted-zone-id "$HOSTED_ZONE" | jq ".ResourceRecordSets[] | select(.Name==\"$SUBDOMAIN.guirao.net.\")")
  ACTION_A=$(if [ -z "$(echo "$RECORDS" | jq 'select(.Type=="A")')" ]; then echo "CREATE"; else echo "UPSERT"; fi)
  ACTION_AAAA=$(if [ -z "$(echo "$RECORDS" | jq 'select(.Type=="AAAA")')" ]; then echo "CREATE"; else echo "UPSERT"; fi)
  aws route53 change-resource-record-sets --hosted-zone-id "$HOSTED_ZONE" --change-batch "{\"Changes\":[{\"Action\":\"$ACTION_A\",\"ResourceRecordSet\":{\"Name\":\"$SUBDOMAIN.guirao.net.\",\"Type\":\"A\",\"TTL\":300,\"ResourceRecords\":[{\"Value\":\"$IPV4\"}]}}]}"
  aws route53 change-resource-record-sets --hosted-zone-id "$HOSTED_ZONE" --change-batch "{\"Changes\":[{\"Action\":\"$ACTION_AAAA\",\"ResourceRecordSet\":{\"Name\":\"$SUBDOMAIN.guirao.net.\",\"Type\":\"AAAA\",\"TTL\":300,\"ResourceRecords\":[{\"Value\":\"$INET6\"}]}}]}"
done

sed -i 's|80|8053|' /etc/lighttpd/lighttpd.conf

reboot now
