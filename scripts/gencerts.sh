#!/bin/sh
## Generate private SSL keys.
## ref: https://stackoverflow.com/questions/10175812/how-to-generate-a-self-signed-ssl-certificate-using-openssl

###############################################################################
# Environment
###############################################################################

CRT_FILE="crt.pem"
KEY_FILE="key.pem"

###############################################################################
# Script
###############################################################################

set -E

## Parse arguments.
for arg in "$@"; do
  case $arg in
    --ip)    IPADD=$2; shift 2;;
    --cname) CNAME=$2; shift 2;;
  esac
done

## Set input values.
[ -z "$IPADD" ] && IPADD="127.0.0.1"
[ -z "$CNAME" ] && CNAME="localhost"

if ! ([ -e "$CRT_FILE" ] && [ -e "$KEY_FILE" ]); then
  ## Generate key pairs and store.
  echo "Generating self-signed certificate for name $CNAME and IP $IPADD..."
  openssl req \
    -x509 \
    -newkey rsa:4096 \
    -keyout $KEY_FILE \
    -out $CRT_FILE \
    -sha256 \
    -days 365 \
    -nodes -subj "/CN=$CNAME" \
    -addext "subjectAltName=DNS:$CNAME,IP:$IPADD"
  echo "Key generation complete!"
fi
