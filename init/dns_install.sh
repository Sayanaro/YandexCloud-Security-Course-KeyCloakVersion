#!/bin/bash
source kc-data.sh

hname=$(hostname)
hostnamectl set-hostname $(hostname).$DomainFQDN

apt-get update
apt-get install -y bind9
apt-get install -y dnsutils
apt-get install -y unzip

# Getting IP Address
ip4=$(/sbin/ip -o -4 addr list eth0 | awk '{print $4}' | cut -d/ -f1)
fwd=$(echo $ip4 | awk '{split($1,p,"."); $1=p[1]"."p[2]"."p[3]"."} 1')"2"
DomainName=$(echo $DomainFQDN | cut -f1 -d".")

# Adding x.x.x.2 forwarder
sudo chmod 777 /etc/bind/named.conf.options
sudo cat <<EOF > /etc/bind/named.conf.options
  options {
          directory "/var/cache/bind";
          // If there is a firewall between you and nameservers you want
          // to talk to, you may need to fix the firewall to allow multiple
          // ports to talk.  See http://www.kb.cert.org/vuls/id/800113
          // If your ISP provided one or more IP addresses for stable
          // nameservers, you probably want to use them as forwarders.
          // Uncomment the following block, and insert the addresses replacing
          // the all-0's placeholder.
          forwarders {
          $fwd;
          };
          //========================================================================
          // If BIND logs error messages about the root key being expired,
          // you will need to update your keys.  See https://www.isc.org/bind-keys
          //========================================================================
          dnssec-validation auto;
          listen-on-v6 { any; };
};
EOF
sudo chmod 644 /etc/bind/named.conf.options

# Adding DNS Zones
chmod 777 /etc/bind/named.conf.local

cat <<EOF >> /etc/bind/named.conf.local
zone "$DomainFQDN" {
  type master;
  file "/etc/bind/db.$DomainFQDN";
};
zone "10.in-addr.arpa" {
  type master;
  file "/etc/bind/db.10";
};
zone "192.in-addr.arpa" {
  type master;
  file "/etc/bind/db.192";
};
zone "172.in-addr.arpa" {
  type master;
  file "/etc/bind/db.172";
};
EOF

chmod 644 /etc/bind/named.conf.local

# Configuring DNS Primary zone
cp /etc/bind/db.local /etc/bind/db.$DomainFQDN

chmod 777 /etc/bind/db.$DomainFQDN
cat <<EOF > /etc/bind/db.$DomainFQDN
;
; BIND data file for $DomainFQDN
;
\$TTL    604800
@       IN      SOA     $DomainName. root.$DomainFQDN. (
                              2         ; Serial
                         604800         ; Refresh
                          86400         ; Retry
                        2419200         ; Expire
                         604800 )       ; Negative Cache TTL
;
@       IN      NS      ns.$DomainFQDN.
@       IN      A       $ip4
@       IN      AAAA    ::1
ns      IN      A       $ip4
$hname  IN      A       $ip4
keycloak IN     A       $ip4
crl     IN     A       $ip4
EOF
chmod 644 /etc/bind/db.$DomainFQDN

# Configuring DNS Reverse Zones
cp /etc/bind/db.127 /etc/bind/db.10
chmod 777 /etc/bind/db.10
cat <<EOF > /etc/bind/db.10
;
; BIND reverse data file for 10.x.x.x net
;
\$TTL    604800
@       IN      SOA     $DomainName. root.$DomainFQDN. (
                              1         ; Serial
                         604800         ; Refresh
                          86400         ; Retry
                        2419200         ; Expire
                         604800 )       ; Negative Cache TTL
;
@       IN      NS      ns.
10   IN      PTR     ns.$DomainFQDN.
EOF
chmod 644 /etc/bind/db.10

cp /etc/bind/db.127 /etc/bind/db.192
chmod 777 /etc/bind/db.192
cat <<EOF > /etc/bind/db.192
;
; BIND reverse data file for 192.x.x.x net
;
\$TTL    604800
@       IN      SOA     $DomainName. root.$DomainFQDN. (
                              1         ; Serial
                         604800         ; Refresh
                          86400         ; Retry
                        2419200         ; Expire
                         604800 )       ; Negative Cache TTL
;
@       IN      NS      ns.
192   IN      PTR     ns.$DomainFQDN.
EOF
chmod 644 /etc/bind/db.192

cp /etc/bind/db.127 /etc/bind/db.172
chmod 777 /etc/bind/db.172
cat <<EOF > /etc/bind/db.172
;
; BIND reverse data file for 172.x.x.x net
;
\$TTL    604800
@       IN      SOA     $DomainName. root.$DomainFQDN. (
                              1         ; Serial
                         604800         ; Refresh
                          86400         ; Retry
                        2419200         ; Expire
                         604800 )       ; Negative Cache TTL
;
@       IN      NS      ns.
172   IN      PTR     ns.$DomainFQDN.
EOF
chmod 644 /etc/bind/db.172

# Restarting bind
systemctl restart bind9

chmod 777 /etc/netplan/01-netcfg.yaml
sudo cat <<EOF >> /etc/netplan/01-netcfg.yaml
      nameservers:
          addresses: [$ip4]
EOF
chmod 644 /etc/netplan/01-netcfg.yaml
netplan apply
