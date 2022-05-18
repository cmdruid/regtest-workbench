#!/bin/sh
## Startup script for tor.

set -E

###############################################################################
# Environment
###############################################################################

DATA_PATH="/data/tor"
SERV_PATH="$DATA_PATH/services"
CONF_PATH="/root/config/tor"
COOK_PATH="/var/lib/tor"
LOGS_PATH="/var/log/tor"

CONF_FILE="$CONF_PATH/torrc"

###############################################################################
# Methods
###############################################################################

get_services_hostname() {
  [ -n "$1" ] && for hostpath in `find $1 -name hostname`; do
    pathname=`basename $(dirname $hostpath) | tr '[:lower:]' '[:upper:]'`
    printf "${pathname}_ONION=$(cat $hostpath)\n"
  done
}

###############################################################################
# Script
###############################################################################

DAEMON_PID=`pgrep tor`

if [ -z "$DAEMON_PID" ]; then

  printf "
=============================================================================
  Starting Tor Daemon
=============================================================================
  \n"

  ## Create missing paths.
  if [ ! -d "$LOGS_PATH" ]; then mkdir -p -m 700 $LOGS_PATH; fi
  if [ ! -d "$SERV_PATH" ]; then mkdir -p -m 700 $SERV_PATH; fi
  if [ ! -d "$COOK_PATH" ]; then mkdir -p -m 700 $COOK_PATH; fi

  ## If config file missing, raise error and exit.
  if [ ! -e "$CONF_FILE" ]; then echo "$CONF_FILE is missing!" && exit 1; fi

  ## Start tor then tail the logfile to search for the completion phrase.
  echo "Starting tor process..."
  tor -f $CONF_FILE; tail -f $LOGS_PATH/notice.log | while read line; do
    echo "$line" && echo "$line" | grep "Bootstrapped 100%"
    if [ $? = 0 ]; then echo "Tor circuit initialized!" && exit 0; fi
  done

else 
  
  echo "Tor daemon is running under PID: $DAEMON_PID"

fi

## Set environment variables for hidden service endpoints.
get_services_hostname $SERV_PATH > $DATA_PATH/hostnames
