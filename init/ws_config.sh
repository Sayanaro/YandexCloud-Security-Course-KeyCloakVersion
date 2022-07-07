#!/bin/bash
source ws-data.sh

zypper install -y -t pattern kde kde_plasma
systemctl enable sddm
systemctl start sddm

# Setting up password for user sles
echo sles:\"$KC_ADM_PASS\" > pass.txt
chpasswd <pass.txt
#

# Installing Google Chrome
zypper addrepo http://dl.google.com/linux/chrome/rpm/stable/x86_64 Google-Chrome
wget https://dl.google.com/linux/linux_signing_key.pub
rpm --import linux_signing_key.pub
zypper -n refresh
zypper install -y -n pwgen google-chrome-stable mozilla-nss-tools

ip4=$(/sbin/ip -o -4 addr list eth0 | awk '{print $4}' | cut -d/ -f1)
fwd=$(echo $ip4 | awk '{split($1,p,"."); $1=p[1]"."p[2]"."p[3]"."} 1')"2"

chmod 777 /etc/resolv.conf
sed -i '$ d' /etc/resolv.conf
echo "nameserver $DNS_IP" >> /etc/resolv.conf
echo "nameserver $fwd" >> /etc/resolv.conf
chmod 644 /etc/resolv.conf

wget "http://crl.$DomainFQDN/intermediate.crt"
wget "http://crl.$DomainFQDN/ca.crt"
wget "http://crl.$DomainFQDN/ca-chain.cert.pem"

runuser -l sles -c "mkdir -p /home/sles/.pki/nssdb"
runuser -l sles -c "certutil -d sql:/home/sles/.pki/nssdb -A -t \"C,,\" -n \"LAB Class1 Root CA\" -i /home/sles/ca.crt"

cp ca.crt /usr/share/pki/trust/anchors
cp intermediate.crt /usr/share/pki/trust/anchors
cp ca.crt /etc/pki/trust/anchors
cp intermediate.crt /etc/pki/trust/anchors
cp ca-chain.cert.pem /etc/pki/trust/anchors
cp ca-chain.cert.pem /usr/share/pki/trust/anchors
update-ca-certificates

#zypper --non-interactive install tightvnc

runuser -l sles -c "umask 0077"
runuser -l sles -c "mkdir -p \"/home/sles/.vnc\""
runuser -l sles -c "chmod go-rwx \"/home/sles/.vnc\""
runuser -l sles -c "vncpasswd -f <<<\"$KC_ADM_PASS\" > \"/home/sles/.vnc/passwd\""

# Creating Desktop sortcut
#ln -s /usr/share/applications/google-chrome.desktop /home/sles/Desktop/google-chrome.desktop
#runuser -l sles -c "vncserver -kill :1"

#runuser -l sles -c "vncserver -geometry 1200x800 -depth 32 -name remote-desktop :1"
