#!/bin/bash
# KeyCloak installation script by Alex Kitaev

# Include variables
source kc-data.sh

while [ ! -f /opt/ca/intermediate/certs/$(hostname).cert.pem ]
do
  sleep 2 # or less like 0.2
done

# Change Timezone
timedatectl set-timezone Europe/Moscow

# Install Packages
apt-get install -y unzip openjdk-17-jre

# This lab emulates secured enterprise environment.
# So we use local 2-tier PKI.
# All paths are hardcoded.
# ATEENTION!
# NEVER DEPLOY CAs AND IDP IN ONE SERVER!!!

# Get Keycloak distro and put files to the right place
curl -sLO https://github.com/keycloak/keycloak/releases/download/$KC_VER/keycloak-$KC_VER.zip
unzip -q keycloak-$KC_VER.zip
rm -f keycloak-$KC_VER/bin/*.bat
mkdir -p /opt/keycloak
cp -R keycloak-$KC_VER/* /opt/keycloak
rm -rf keycloak-$KC_VER/ keycloak-$KC_VER.zip 

# Import configuration from realm config file
export PATH=$PATH:/opt/keycloak/bin
kc.sh build
cp /opt/ca/intermediate/certs/$(hostname).cert.pem /opt/keycloak
cp /opt/ca/intermediate/private/$(hostname).key.pem /opt/keycloak

# Prepare systemd things
groupadd keycloak
useradd -r -g keycloak -d /opt/keycloak -s /sbin/nologin keycloak
chown -R keycloak:keycloak /opt/keycloak
chmod o+x /opt/keycloak/bin/

cat <<EOF > /lib/systemd/system/keycloak.service
[Unit]
Description=Keycloak Service
After=network.target

[Service]
User=keycloak
Group=keycloak
PIDFile=/var/run/keycloak/keycloak.pid
WorkingDirectory=/opt/keycloak
Environment="KEYCLOAK_ADMIN=$KC_ADM_USER"
Environment="KEYCLOAK_ADMIN_PASSWORD=$KC_ADM_PASS"
ExecStart=/opt/keycloak/bin/kc.sh start \\
  --hostname=$(hostname) \\
  --https-certificate-file=/opt/keycloak/$(hostname).cert.pem \\
  --https-certificate-key-file=/opt/keycloak/$(hostname).key.pem \\
  --db-url-database=$PG_DB_NAME \\
  --db-url-host=$PG_DB_HOST \\
  --db-username=$PG_DB_USER \\
  --db-password=$PG_DB_PASS \\
  --hostname-strict=true \\
  --http-enabled=false \\
  --https-protocols=TLSv1.3,TLSv1.2 \\
  --https-port=$KC_PORT \\
  --log-level=INFO

[Install]
WantedBy=multi-user.target
EOF

# Start Keycloak via systemd
systemctl daemon-reload
sleep 3
systemctl start keycloak
systemctl enable keycloak

# Waiting until KC has been started
while :; do
  curl -sf "https://$(hostname):$KC_PORT" -o /dev/null && break
  sleep 10
done

kc.sh import --file=realm.json

