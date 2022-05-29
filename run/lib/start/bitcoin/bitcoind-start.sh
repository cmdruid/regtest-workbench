#!/bin/sh
## Start script for bitcoind.

set -E

###############################################################################
# Environment
###############################################################################

BIN_NAME="bitcoind"

DATA_PATH="/data/bitcoin"
CONF_PATH="$HOME/config/bitcoin"
LINK_PATH="$HOME/.bitcoin"
LOGS_PATH="/var/log/bitcoin"

CONF_FILE="$CONF_PATH/bitcoin.conf"
LINK_FILE="$LINK_PATH/bitcoin.conf"
AUTH_FILE="$DATA_PATH/rpcauth.conf"
LOGS_FILE="$LOGS_PATH/debug.log"

###############################################################################
# Methods
###############################################################################

fprint() {
  col_offset=2
  newline=`printf %s "$1" | cut -f ${col_offset}- -d ' '`
  printf '%s\n' "$IND $newline"
}

###############################################################################
# Script
###############################################################################

## Create any missing paths.
if [ ! -d "$DATA_PATH" ]; then mkdir -p "$DATA_PATH"; fi
if [ ! -d "$LINK_PATH" ]; then mkdir -p "$LINK_PATH"; fi
if [ ! -d "$LOGS_PATH" ]; then mkdir -p "$LOGS_PATH"; fi

## Make sure configuration file is linked.
if [ ! -e "$LINK_FILE" ]; then
  printf "Adding symlink for $LINK_FILE ..."
  ln -s $CONF_FILE $LINK_FILE
  templ ok
fi

if [ -z "$(which $BIN_NAME)" ]; then echo "Binary for $BIN_NAME is missing!" && exit 1; fi

DAEMON_PID=`lsof -c $BIN_NAME | grep "$(which $BIN_NAME)" | awk '{print $2}'`

if [ -z "$DAEMON_PID" ]; then

  ## Add rpcauth credentials.
  if [ ! -e "$AUTH_FILE" ]; then
    printf "Generating RPC credentials"
    rpcauth --save="$DATA_PATH"
    templ ok
  fi

  ## Declare base config string.
  config="-rpcauth=$(cat $AUTH_FILE)"

  ## If tor is running, add tor configuration.
  if [ -n "$(pgrep tor)" ]; then
    config="$config -onion=127.0.0.1:9050" ## <-- Fix This
  fi

  ## Start bitcoind then tail the logfile to search for the completion phrase.
  echo && printf "Starting bitcoin daemon"; templ prog
  bitcoind $config > /dev/null 2>&1; tail -f $LOGS_FILE | while read line; do
    [ -n "$DEVMODE" ] && fprint "$line"
    echo "$line" | grep "init message: Done loading" > /dev/null 2>&1
    if [ $? = 0 ]; then 
      printf "$IND Bitcoin core loaded!"; templ ok && exit 0;
    fi
  done

else 
  printf "Bitcoin daemon is running under PID: $(templ hlight $DAEMON_PID)"; templ ok
fi