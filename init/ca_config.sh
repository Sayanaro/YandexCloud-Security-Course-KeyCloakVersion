#!/bin/bash
source kc-data.sh

while [ ! -f /etc/bind/db.172 ]
do
  sleep 2 # or less like 0.2
done

# Installing pre-requisites
apt-get install -y wget
apt-get install -y ca-certificates
apt-get install -y apache2

# Creating catalogs
mkdir /opt/ca
cd /opt/ca
chmod 777 /opt/ca
mkdir certs crl newcerts private
touch index.txt
echo 1000 > serial
echo 20 > /opt/ca/crlnumber
chmod 755 /opt/ca
chmod 700 private

# Downloading OpenSSL config fo root ca
wget hhttps://raw.githubusercontent.com/Sayanaro/YandexCloud-Security-Course-KeyCloackVersion/master/openssl.cnf

# Creating self-signed Root CA certificate with 10 years lifetime
openssl req -new -x509 -newkey rsa:4096 -days 3650 -config openssl.cnf -sha256 -extensions v3_ca -nodes -x509 \
    -subj "/C=RU/ST=Moscow/L=Moscow/O=Yandex Pacticum/OU=Lab/CN=LAB CLASS1 Root CA" \
    -keyout /opt/ca/private/ca.key.pem -out /opt/ca/certs/ca.cert.pem

echo "crlDistributionPoints = URI:http://crl.$DomainFQDN/rootca.crl" >> /opt/ca/openssl.cnf
echo "authorityInfoAccess = caIssuers;URI:http://crl.$DomainFQDN/ca.crt" >> /opt/ca/openssl.cnf

openssl ca -config /opt/ca/openssl.cnf \
      -gencrl -out /opt/ca/crl/rootca.crl.pem

# Making ca cert trustable
cp /opt/ca/certs/ca.cert.pem /usr/local/share/ca-certificates/ca.cert.crt
update-ca-certificates

# Creating Intermediate Issuing CA
mkdir /opt/ca/intermediate

cd /opt/ca/intermediate
mkdir certs crl csr newcerts private
chmod 777 /opt/ca/intermediate
touch index.txt
echo 1000 > serial
echo 1000 > /opt/ca/intermediate/crlnumber
wget https://raw.githubusercontent.com/Sayanaro/YandexCloud-Security-Course-KeyCloackVersion/master/intermediate/openssl.cnf

chmod 755 /opt/ca/intermediate
chmod 700 private

cd /opt/ca
# Creating Intermediate CA PKCS#10 request
openssl req -new -newkey rsa:4096 -config /opt/ca/intermediate/openssl.cnf -sha256 -nodes \
    -subj "/C=RU/ST=Moscow/L=Moscow/O=Yandex Pacticum/OU=Lab/CN=LAB Issuing CA" \
    -keyout /opt/ca/intermediate/private/intermediate.key.pem -out /opt/ca/intermediate/csr/intermediate.csr.pem

chmod 400 /opt/ca/intermediate/private/intermediate.key.pem

# Signing Intermediate CA Request
openssl ca -batch -config openssl.cnf -extensions v3_intermediate_ca \
      -days 1825 -notext -md sha256 \
      -in /opt/ca/intermediate/csr/intermediate.csr.pem \
      -out /opt/ca/intermediate/certs/intermediate.cert.pem

chmod 444 intermediate/certs/intermediate.cert.pem

# Creating chain
cat /opt/ca/intermediate/certs/intermediate.cert.pem \
      /opt/ca/certs/ca.cert.pem > /opt/ca/intermediate/certs/ca-chain.cert.pem

# Adding CDP and AIA extensions
echo "crlDistributionPoints = URI:http://crl.$DomainFQDN/intermediate.crl" >> /opt/ca/intermediate/openssl.cnf
echo "authorityInfoAccess = caIssuers;URI:http://crl.$DomainFQDN/intermediate.crt" >> /opt/ca/intermediate/openssl.cnf

# Creating Intermediate CA CRL
openssl ca -config /opt/ca/intermediate/openssl.cnf \
      -gencrl -out /opt/ca/intermediate/crl/intermediate.crl.pem

cp /opt/ca/intermediate/certs/intermediate.cert.pem /usr/local/share/ca-certificates/intermediate.cert.crt
update-ca-certificates

# Configuring Apache2
sudo chmod 777 /etc/apache2/sites-available/000-default.conf

cat <<EOF > /etc/apache2/sites-available/000-default.conf
<VirtualHost *:80>
        # Basic server information
        ServerAdmin user@yantoso.com
        ServerName crl.$DomainFQDN

        # Set-up serving directory
        DocumentRoot /var/www/crl.$DomainFQDN
        <Directory /var/www/crl.$DomainFQDN/>
                Options Indexes
                AllowOverride None
        </Directory>

        # Setup logs
        LogLevel warn
        ErrorLog /var/log/apache2/crl.$DomainFQDN/error.log
        CustomLog /var/log/apache2/crl.$DomainFQDN/access.log combined
</VirtualHost>
EOF

sudo chmod 644 /etc/apache2/sites-available/000-default.conf

mkdir /var/www/crl.$DomainFQDN/
mkdir /var/log/apache2/crl.$DomainFQDN/
chown root.adm /var/log/apache2/crl.$DomainFQDN/
chmod 750 /var/log/apache2/crl.$DomainFQDN/

# Copying CRL and certificates to Apache folder
cp /opt/ca/intermediate/crl/intermediate.crl.pem /var/www/crl.$DomainFQDN/intermediate.crl
cp /opt/ca/intermediate/certs/intermediate.cert.pem /var/www/crl.$DomainFQDN/intermediate.crt
cp /opt/ca/crl/rootca.crl.pem /var/www/crl.$DomainFQDN/rootca.crl
cp /opt/ca/certs/ca.cert.pem /var/www/crl.$DomainFQDN/ca.crt
cp /opt/ca/intermediate/certs/ca-chain.cert.pem /var/www/crl.$DomainFQDN/
systemctl restart apache2

cd /opt/ca

# Creating certificate for KeyCloak
echo "subjectAltName = DNS:$(hostname)" >> /opt/ca/intermediate/openssl.cnf

openssl req -new -sha256 -newkey rsa:2048 -config /opt/ca/intermediate/openssl.cnf -nodes \
    -subj "/C=RU/ST=Moscow/L=Moscow/O=Yandex Pacticum/OU=Lab/CN=$(hostname)" \
    -addext "subjectAltName = DNS:$(hostname)" \
    -keyout /opt/ca/intermediate/private/$(hostname).key.pem  -out /opt/ca/intermediate/csr/$(hostname).csr.pem

openssl ca -batch -config /opt/ca/intermediate/openssl.cnf \
      -extensions server_cert -days 365 -notext -md sha256 \
      -in /opt/ca/intermediate/csr/$(hostname).csr.pem \
      -out /opt/ca/intermediate/certs/$(hostname).cert.pem
chmod 777 /opt/ca/intermediate/certs/$(hostname).cert.pem

sed -i '$ d' /opt/ca/intermediate/openssl.cnf

# Adding chan to cert
cat /opt/ca/intermediate/certs/$(hostname).cert.pem \
      /opt/ca/intermediate/certs/intermediate.cert.pem \
      /opt/ca/certs/ca.cert.pem > /opt/ca/intermediate/certs/ca-chain-cert.pem

cp /opt/ca/intermediate/certs/ca-chain-cert.pem /var/www/crl.$DomainFQDN/
systemctl restart apache2
