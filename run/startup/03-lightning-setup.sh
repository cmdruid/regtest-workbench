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

###############################################################################
# Script
###############################################################################

printf "
=============================================================================
  Core Lightning Configuration
=============================================================================
\n"

if [ -z "$(pgrep bitcoind)" ]; then echo "Bitcoind is not running!" && exit 1; fi

## Create any missing paths.
if [ ! -d "$DATA_PATH" ]; then mkdir -p "$DATA_PATH"; fi
if [ ! -d "$LOGS_PATH" ]; then mkdir -p "$LOGS_PATH"; fi

## Make sure configuration file is linked.
if [ ! -e "$LINK_FILE" ]; then
  printf "Adding symlink for $LINK_FILE ... "
  ln -s $CONF_FILE $LINK_FILE
  printf %b\\n "done."
fi

## Check for existing process.
DAEMON_PID=`pgrep lightningd`

if [ -z "$DAEMON_PID" ]; then

  ## Declare base config string.
  config="--daemon --conf=$CONF_FILE"

  ## If tor is running, add tor configuration.
  if [ -n "$(pgrep tor)" ]; then
    config="$config --proxy=127.0.0.1:9050"
  fi

  ## Configure sparko keys.
  config="$config $(sh -c $WORK_PATH/lib/sparko-config.sh)"

  ## Link the regtest interface for compatibility.
  if [ ! -e "$LINK_PATH/regtest" ]; then
    echo "Adding symlink for regtest network RPC ..."
    ln -s $DATA_PATH/regtest $LINK_PATH/regtest
  fi

  ## Start lightning and wait for it to load.
  lightningd $config; tail -f $LOGS_FILE | while read line; do
    echo "$line" && echo "$line" | grep "Server started with public key"
    if [ $? = 0 ]; then echo "Lightning daemon running on regtest network!" && exit 0; fi
  done

else echo "Lightning daemon is running under PID: $DAEMON_PID"; fi

## Adding links to plugins
if [ -d "$PLUG_PATH/noise" ]; then
  printf "Enabling noise plugin ..."
  lightning-cli plugin start $PLUG_PATH/noise/noise.py > /dev/null 2>&1 && %b\\n "done."
fi

## Update share configuration.
sh -c $WORK_PATH/lib/share/lightning-share-config.sh
if [ -e "$KEYS_FILE" ]; then cp $KEYS_FILE "$PEER_PATH"; fi
if [ -e "$CRED_FILE" ]; then cp $CRED_FILE "$PEER_PATH"; fi

###############################################################################
# Payment Configuration
###############################################################################

## Generate a funding address.
if [ ! -e "$FUND_FILE" ] || [ -z "$(cat $FUND_FILE)" ]; then
  printf "Generating new payment address for lightning ... "
  lightning-cli newaddr | jgrep bech32 > $FUND_FILE
  printf %b\\n " done."
fi

## Configure channel settings.
lightning-cli funderupdate match 100 > /dev/null 2>&1
lightning-cli autocleaninvoice 60 > /dev/null 2>&1

###############################################################################
# Peer Connection
###############################################################################

if [ -n "$ADD_PEERS" ]; then
  for peer in "$(printf $ADD_PEERS | tr ',' '\n')"; do
    
    ## Search for peer file in peers path.
    printf "Searching for connection settings from $peer ... "
    config=`find "$SHARE_PATH/$peer"* -name lightning-peer.conf`

    ## Exit out if peer file is not found.
    if [ ! -e "$config" ]; then printf %b\\n "failed!" && continue; fi
    printf %b\\n "done."

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
      printf "Peering to host $node_id@$peer_host ... "
      lightning-cli connect "$node_id@$peer_host" > /dev/null
      printf %b\\n "done."
    fi

  done
fi
