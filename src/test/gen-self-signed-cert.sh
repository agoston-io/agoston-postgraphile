#!/usr/bin/env bash

set -e

# Ref. https://stackoverflow.com/questions/7580508/getting-chrome-to-accept-self-signed-localhost-certificate

if [ -z "${1}" ]; then
    echo "USAGE: ./self-signed-ssl-for-nginx.sh <domain-to-certify> <host to copy .crt|.key files in /etc/nginx/ssl>"
    exit 1
fi

ROOT_DOMAIN="${1}"
# Derive vars
ROOT_DOMAIN_CA="${ROOT_DOMAIN}-ca"
# Specify where we will install
SSL_DIR=~/certificate
mkdir -p ${SSL_DIR}
SSL_INSTALL_DIR=/etc/ssl
# Set our CSR variables
SUBJ="
C=CH
ST=Zurich
O=Agoston
localityName=Zurich
commonName=${ROOT_DOMAIN}
organizationalUnitName=Agoston
emailAddress=code@agoston.o
"

# Cleanup previous if any
rm -f ${SSL_DIR}/${ROOT_DOMAIN_CA}.key
rm -f ${SSL_DIR}/${ROOT_DOMAIN_CA}.pem
rm -f ${SSL_DIR}/${ROOT_DOMAIN}.key
rm -f ${SSL_DIR}/${ROOT_DOMAIN}.csr
rm -f ${SSL_DIR}/${ROOT_DOMAIN}.cst
rm -f ${SSL_DIR}/${ROOT_DOMAIN}.ext

######################
# Become a Certificate Authority
######################
echo "Generate private key"
openssl genrsa -out ${SSL_DIR}/${ROOT_DOMAIN_CA}.key 2048
echo "Generate root certificate"
openssl req -x509 -new -subj "$(echo -n "$SUBJ" | tr "\n" "/")" -nodes -key ${SSL_DIR}/${ROOT_DOMAIN_CA}.key -sha256 -days 825 -out ${SSL_DIR}/${ROOT_DOMAIN_CA}.pem

######################
# Create CA-signed certs
######################
echo "Create a certificate-signing request"
openssl genrsa -out ${SSL_DIR}/${ROOT_DOMAIN}.key 2048
echo "Generate a private key"
openssl req -new -subj "$(echo -n "$SUBJ" | tr "\n" "/")" -key ${SSL_DIR}/${ROOT_DOMAIN}.key -out ${SSL_DIR}/${ROOT_DOMAIN}.csr
echo "Create a config file for the extensions"
>${SSL_DIR}/${ROOT_DOMAIN}.ext cat <<-EOF
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment
subjectAltName = @alt_names
[alt_names]
DNS.1 = ${ROOT_DOMAIN}
DNS.2 = www.${ROOT_DOMAIN}
DNS.3 = backend.${ROOT_DOMAIN}
DNS.4 = 2c059b20-a200-45aa-8492-0e2891e14832.backend.${ROOT_DOMAIN}
IP.1 = 192.168.56.56
IP.2 = 192.168.56.60
IP.2 = 192.168.56.101
EOF
# Create the signed certificate
openssl x509 -req -in ${SSL_DIR}/${ROOT_DOMAIN}.csr -CA ${SSL_DIR}/${ROOT_DOMAIN_CA}.pem -CAkey ${SSL_DIR}/${ROOT_DOMAIN_CA}.key -CAcreateserial \
-out ${SSL_DIR}/${ROOT_DOMAIN}.crt -days 825 -sha256 -extfile ${SSL_DIR}/${ROOT_DOMAIN}.ext

sudo cp ${SSL_DIR}/${ROOT_DOMAIN}.{crt,key} ${SSL_INSTALL_DIR}/

echo "

1. Check domain validation

   openssl verify \\
        -CAfile ${SSL_DIR}/${ROOT_DOMAIN_CA}.pem \\
        -verify_hostname ${ROOT_DOMAIN} \\
        ${SSL_DIR}/${ROOT_DOMAIN}.crt

2. Add this to your nginx config:

    ssl_certificate     ${SSL_DIR}/${ROOT_DOMAIN}.crt;
    ssl_certificate_key ${SSL_DIR}/${ROOT_DOMAIN}.key;

3. Import ${SSL_DIR}/${ROOT_DOMAIN_CA}.pem as an 'Authority' (not into 'Your Certificates')
   in your Chrome settings (Settings > Manage certificates > Authorities > Import)

4. Chrome Users:
        Go to Settings.
        Click advanced settings at the bottom.
        Scroll down to Network and click 'Change Proxy Settings'
        Go to the Content tab and then click 'Clear SSL State'

"