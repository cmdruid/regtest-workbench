#!/usr/bin/env bash
## Start script for lightning daemon.

set -E

###############################################################################
# Environment
###############################################################################

BIN_NAME="lightningd"

DATA_PATH="/data/lightning"
CONF_PATH="$HOME/config/lightning"
LINK_PATH="$HOME/.lightning"
LOGS_PATH="/var/log/lightning"
PEER_PATH="$SHAREPATH/$HOSTNAME"

CONF_FILE="$CONF_PATH/config"
LINK_FILE="$LINK_PATH/config"
LOGS_FILE="$LOGS_PATH/lightningd.log"
KEYS_FILE="$DATA_PATH/sparko.keys"
CRED_FILE="$DATA_PATH/sparko.login"

###############################################################################
# Methods
###############################################################################

fprint() {
  col_offset=2
  prefix="$(fgc 215 '|')"
  newline=`printf %s "$1" | cut -f ${col_offset}- -d ' '`
  printf '%s\n' "$IND $newline"
}

###############################################################################
# Script
###############################################################################

if [ -z "$(which $BIN_NAME)" ]; then echo "Binary for $BIN_NAME is missing!" && exit 1; fi

DAEMON_PID=`lsof -c $BIN_NAME | grep "$(which $BIN_NAME)" | awk '{print $2}'`

if [ -z "$DAEMON_PID" ]; then

  ## Make sure configuration file is linked.
  if [ ! -e "$LINK_FILE" ]; then
    printf "Adding symlink for $LINK_FILE"
    ln -s $CONF_FILE $LINK_FILE
    templ ok
  fi

  ## Declare base config string.
  config="--daemon --conf=$CONF_FILE"

  ## If tor is running, add tor configuration.
  if [ -n "$(pgrep tor)" ]; then
    printf "Adding tor proxy settings to lightningd"
    config="$config --proxy=127.0.0.1:9050"
    templ ok
  fi

  ## Configure sparko keys.
  printf "Adding sparko key configuration to lightningd"
  config="$config $(sh -c $LIBPATH/share/sparko-share-config.sh)"
  templ ok

  ## Link the regtest interface for compatibility.
  if [ ! -e "$LINK_PATH/regtest" ]; then
    printf "Adding symlink for regtest network RPC"
    ln -s $DATA_PATH/regtest $LINK_PATH/regtest
    templ ok
  fi

  ## Start lightning and wait for it to load.
  echo && printf "Starting lightning daemon" && templ prog
  lightningd $config > /dev/null 2>&1; tail -f $LOGS_FILE | while read line; do
    fprint "$line" && echo "$line" | grep "Server started with public key" > /dev/null 2>&1
    if [ $? = 0 ]; then
      printf "$IND Lightning daemon running on regtest network!"
      templ ok && echo && exit 0
    fi
  done

else 
  printf "Lightning daemon is running under PID: $(templ hlight $DAEMON_PID)" && templ ok
fi

## Update share configuration.
printf "Updating lightning configuration files in $SHAREPATH"
sh -c $LIBPATH/share/lightning-share-config.sh
if [ -e "$KEYS_FILE" ]; then cp $KEYS_FILE "$PEER_PATH"; fi
if [ -e "$CRED_FILE" ]; then cp $CRED_FILE "$PEER_PATH"; fi
templ ok