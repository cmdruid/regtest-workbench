#!/bin/sh
## Startup script for tor.

. $ENV_FILE && set -E

###############################################################################
# Environment
###############################################################################

DATA_PATH="/data/tor"
SERV_PATH="$DATA_PATH/services"
CONF_PATH="/etc/tor/torrc"
LOG_PATH="/var/log/tor/notice.log"

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

if [ -z "$DAEMON_PID" ] && [ -z "$DISABLE_TOR" ]; then

  printf "
=============================================================================
  Starting Tor Daemon
=============================================================================
  \n"

  ## If missing, create tor services path.
  if [ ! -d "$SERV_PATH" ]; then
    echo "Adding persistent data directory for tor ..."
    mkdir -p -m 700 $SERV_PATH
  fi

  ## Start tor then tail the logfile to search for the completion phrase.
  echo "Starting tor process..."
  tor -f $CONF_PATH; tail -f $LOG_PATH | while read line; do
    echo "$line" && echo "$line" | grep "Bootstrapped 100%"
    if [ $? = 0 ]; then echo "Tor circuit initialized!" && exit 0; fi
  done

else echo "Tor daemon is running under PID: $DAEMON_PID"; fi

## Set environment variables for hidden service endpoints.
get_services_hostname $SERV_PATH > $DATA_PATH/hostnames
