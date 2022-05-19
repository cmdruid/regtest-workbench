#!/bin/sh
## Start script for lightning daemon.

set -E

###############################################################################
# Environment
###############################################################################

DATA_PATH="/data/lightning"
CONF_PATH="$HOME/config/lightning"
PLUG_PATH="$HOME/run/plugins"
LINK_PATH="$HOME/.lightning"
PEER_PATH="$SHARE_PATH/$HOSTNAME"
LOGS_PATH="/var/log/lightning"

CONF_FILE="$CONF_PATH/config"
LINK_FILE="$LINK_PATH/config"
KEYS_FILE="$DATA_PATH/sparko.keys"
CRED_FILE="$DATA_PATH/sparko.login"
PEER_FILE="$PEER_PATH/lightning-peer.conf"
LOGS_FILE="$LOGS_PATH/lightningd.log"
FUND_FILE="$DATA_PATH/fund.address"

###############################################################################
# Methods
###############################################################################

is_node_connected() {
  [ -n "$1" ] && [ -n "$(lightning-cli listpeers | jgrep id | grep $1)" ]
}

fprint() {
  newline=`printf "%.115s" "$1" | cut -f 2- -d ' '`
  printf %b\\n "$(fgc 215 "|") $newline"
}

###############################################################################
# Script
###############################################################################

if [ "$?" -ne 0 ]; then exit 1; fi

templ banner "Lightning Core Configuration"

if [ -z "$(pgrep bitcoind)" ]; then echo "Bitcoind is not running!" && exit 1; fi

## Create any missing paths.
if [ ! -d "$DATA_PATH" ]; then mkdir -p "$DATA_PATH"; fi
if [ ! -d "$LOGS_PATH" ]; then mkdir -p "$LOGS_PATH"; fi

## Make sure configuration file is linked.
if [ ! -e "$LINK_FILE" ]; then
  printf "Adding symlink for $LINK_FILE"
  ln -s $CONF_FILE $LINK_FILE
  templ ok
fi

## Check for existing process.
DAEMON_PID=`pgrep lightningd`

if [ -z "$DAEMON_PID" ]; then

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
  config="$config $(sh -c $LIB_PATH/share/sparko-share-config.sh)"
  templ ok

  ## Link the regtest interface for compatibility.
  if [ ! -e "$LINK_PATH/regtest" ]; then
    printf "Adding symlink for regtest network RPC"
    ln -s $DATA_PATH/regtest $LINK_PATH/regtest
    templ ok
  fi

  ## Start lightning and wait for it to load.
  printf "Starting lightning daemon" && templ prog
  lightningd $config; tail -f $LOGS_FILE | while read line; do
    fprint "$line" && echo "$line" | grep "Server started with public key"
    if [ $? = 0 ]; then
      printf "$(fgc 215 "|") Lightning daemon running on regtest network!"
      templ ok && exit 0
    fi
  done
  echo

else 
  printf "Lightning daemon is running under PID: $(templ hlight $DAEMON_PID)" && templ ok
fi

## Adding links to plugins
if [ -d "$PLUG_PATH" ]; then
  for plugin in `find $PLUG_PATH -maxdepth 1 -type d`; do
    name=$(basename $plugin)
    if case $name in .*) ;; *) false;; esac; then continue; fi
    if [ -e "$plugin/$name.py" ]; then
      printf "Enabling $name plugin"
      lightning-cli plugin start $PLUG_PATH/$name/$name.py > /dev/null 2>&1
      templ ok
    fi
  done
fi

## Update share configuration.
printf "Updating lightning configuration files in $SHARE_PATH"
sh -c $WORK_PATH/lib/share/lightning-share-config.sh
if [ -e "$KEYS_FILE" ]; then cp $KEYS_FILE "$PEER_PATH"; fi
if [ -e "$CRED_FILE" ]; then cp $CRED_FILE "$PEER_PATH"; fi
templ ok

###############################################################################
# Payment Configuration
###############################################################################

## Generate a funding address.
if [ ! -e "$FUND_FILE" ] || [ -z "$(cat $FUND_FILE)" ]; then
  printf "Generating new payment address for lightning"
  lightning-cli newaddr | jgrep bech32 > $FUND_FILE
  templ ok
fi

## Configure channel settings.
lightning-cli funderupdate match 100 > /dev/null 2>&1
lightning-cli autocleaninvoice 60 > /dev/null 2>&1

###############################################################################
# Peer Connection
###############################################################################

if [ -n "$PEER_LIST" ]; then
  for peer in $(printf $PEER_LIST | tr ',' ' '); do
    
    ## Search for peer file in peers path.
    printf "Searching for connection settings from $peer"
    config=`find "$SHARE_PATH/$peer"* -name lightning-peer.conf`

    ## Exit out if peer file is not found.
    if [ ! -e "$config" ]; then templ fail && continue; fi
    templ ok

    ## Parse current peering info.
    onion_host=`cat $config | kgrep ONION_NAME`
    node_id="$(cat $config | kgrep NODE_ID)"
    if [ -n "$(pgrep tor)" ] && [ -n "$onion_host" ]; then
      peer_host="$onion_host"
    else
      peer_host="$(cat $config | kgrep HOST_NAME)"
    fi

    ## If valid peer, then connect to node.
    if ! is_node_connected $node_id; then
      printf "Peering to host $peer"
      lightning-cli connect "$node_id@$peer_host" > /dev/null
      templ conn
    fi

  done
fi
