#!/usr/bin/env bash
## Start script for RTL's CL-REST interface.

set -E

###############################################################################
# Environment
###############################################################################

SRC_PATH="/root/.lightning/cl-rest"

CERT_PATH="/data/certs"
CERT_LINK="$SRC_PATH/certs"

CONF_NAME="cl-rest-config.json"
CONF_FILE="/root/config/$CONF_NAME"

LOG_FILE="/var/log/lightning/cl-rest.log"
REST_FILE="cln-rest.conf"

ONION_HOST="/data/tor/services/cln/hostname"
DEFAULT_CLN_REST_PORT=3001

###############################################################################
# Methods
###############################################################################

finish() {
  if [ "$?" -ne 0 ]; then templ fail && exit 1; fi
}

###############################################################################
# Script
###############################################################################

trap finish EXIT

templ "CL-REST Configuration"

if [ -z "$CLN_REST_PORT" ]; then CLN_REST_PORT=$DEFAULT_CLN_REST_PORT; fi

DAEMON_PID=`pgrep -f "node cl-rest.js"`

if [ -z "$DAEMON_PID" ]; then

  printf "Starting CL-REST server:\n"
  
  ## Create certificate directory if does not exist.
  if [ ! -d "$CERT_PATH" ]; then 
    printf "| Adding data directory for rest certificates ...\n"
    mkdir -p $CERT_PATH
  fi

  ## Symlink configuration file to root of project.
  if [ ! -e "$SRC_PATH/$CONF_NAME" ]; then
    printf "| Copying configuration file to project ...\n"
    cp $CONF_FILE $CERT_LINK "$SRC_PATH/$CONF_NAME"
  fi

  ## Symlink the certificates for the REST API to persistent storage.
  if [ ! -e "$CERT_LINK" ]; then
    printf "| Adding symlink for access macaroon ...\n"
    ln -s $CERT_PATH $CERT_LINK
  fi

  ## Start the CL-REST server.
  cd $SRC_PATH && node cl-rest.js > $LOG_FILE &

  # Wait for lightningd to load, then start other services.
  tail -f $LOG_FILE | while read line; do
    printf "| $line\n" && echo "$line" | grep "cl-rest api server is ready"
    if [ $? = 0 ]; then 
      printf "| CL-REST server is now running!" 
      templ ok && exit 0
    fi
  done

else printf "CL-REST process is running under PID: $(templ hlight $DAEMON_PID)\n"; fi

###############################################################################
# Share Configuration
###############################################################################

## Get active hostname.
if [ -n "$(pgrep tor)" ] && [ -e "$ONION_HOST" ]; then 
  CLN_REST_HOST=`cat $ONION_HOST` 
else 
  CLN_REST_HOST="$HOSTNAME"
fi

## Generate configuration.
printf "
## CLN-REST Configuration
REST_HOST=$CLN_REST_HOST
REST_PORT=$CLN_REST_PORT
AUTH_TOKEN=$(cat $CERT_PATH/access.macaroon | xxd -p -c 1000)
" > $SHAREPATH/$HOSTNAME/$REST_FILE