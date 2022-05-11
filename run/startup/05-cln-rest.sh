#!/bin/sh
## Start script for RTL's CL-REST interface.

. $ENV_FILE && set -E

###############################################################################
# Environment
###############################################################################

CERT_PATH="/data/certs"
CERT_LINK="/root/cl-rest/certs"
LOG_PATH="/var/log/cl-rest.log"
REST_FILE="cln-rest.conf"

CLNREST_ONION_HOST="/data/tor/services/cln-rest/hostname"
DEFAULT_CLNREST_PORT=3001

###############################################################################
# Script
###############################################################################

if [ -z "$CLNREST_PORT" ]; then CLNREST_PORT=$DEFAULT_CLNREST_PORT; fi

DAEMON_PID=`pgrep -f "node cl-rest.js"`

if [ -z "$DAEMON_PID" ]; then

  printf "
=============================================================================
  Starting CL-REST Server
=============================================================================
  \n"
  
  ## Create certificate directory if does not exist.
  if [ ! -d "$CERT_PATH" ]; then 
    echo "Adding persistent data directory for rest certificates ..."
    mkdir -p $CERT_PATH
  fi

  ## Symlink the certificates for the REST API to persistent storage.
  if [ ! -e "$CERT_LINK" ]; then
    echo "Adding symlink for access macaroon ..."
    ln -s $CERT_PATH $CERT_LINK
  fi

  ## Start the CL-REST server.
  cd /root/cl-rest && node cl-rest.js > $LOG_PATH &

  # Wait for lightningd to load, then start other services.
  tail -f $LOG_PATH | while read line; do
    echo "$line" && echo "$line" | grep "cl-rest api server is ready"
    if [ $? = 0 ]; then echo "CL-REST server is now running!" && exit 0; fi
  done

else echo "CL-REST process is running under PID: $DAEMON_PID"; fi

###############################################################################
# Share Configuration
###############################################################################

## Generate configuration.
rest_host=`cat $CLNREST_ONION_HOST || printf $HOSTNAME`
auth_token=`cat $CERT_PATH/access.macaroon | xxd -p -c 1000`
base_conf="## CLN-REST Configuration\nREST_HOST=$rest_host\nREST_PORT=$CLNREST_PORT\nAUTH_TOKEN=$auth_token"
printf %b\\n "$base_conf" > $SHARE_PATH/$HOSTNAME/$REST_FILE
