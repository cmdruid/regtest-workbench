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

fprint() {
  col_offset=5
  prefix="$(fgc 215 '|')"
  newline=`printf %s "$1" | cut -f ${col_offset}- -d ' '`
  printf '%s\n' "$prefix $newline"
}

###############################################################################
# Script
###############################################################################

templ banner "Tor Configuration"

DAEMON_PID=`pgrep tor`

if [ -z "$DAEMON_PID" ]; then

  ## Create missing paths.
  if [ ! -d "$LOGS_PATH" ]; then mkdir -p -m 700 $LOGS_PATH; fi
  if [ ! -d "$SERV_PATH" ]; then mkdir -p -m 700 $SERV_PATH; fi
  if [ ! -d "$COOK_PATH" ]; then mkdir -p -m 700 $COOK_PATH; fi

  ## If config file missing, raise error and exit.
  if [ ! -e "$CONF_FILE" ]; then echo "$CONF_FILE is missing!" && exit 1; fi

  ## Start tor then tail the logfile to search for the completion phrase.
  printf "Initializing tor" && templ prog
  tor -f $CONF_FILE > /dev/null 2>&1; tail -f $LOGS_PATH/notice.log | while read line; do
    fprint "$line" && echo "$line" | grep "Bootstrapped 100%" > /dev/null 2>&1
    if [ $? = 0 ]; then 
      printf "$(fgc 215 "|") Tor initialized!"
      templ ok && exit 0
    fi
  done;

else 
  
  printf "Tor daemon is running under PID: $(templ hlight $DAEMON_PID)" && templ ok

fi

## Set environment variables for hidden service endpoints.
get_services_hostname $SERV_PATH > $DATA_PATH/hostnames
