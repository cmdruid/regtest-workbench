#!/bin/sh
## Start script for lightning daemon.

set -E

###############################################################################
# Environment
###############################################################################

DATA_PATH="/data/lightning"
PLUG_PATH="$HOME/run/plugins"
PEER_PATH="$SHARE_PATH/$HOSTNAME"

PEER_FILE="$PEER_PATH/lightning-peer.conf"
FUND_FILE="$DATA_PATH/fund.address"

###############################################################################
# Methods
###############################################################################

is_node_configured() {
  [ -n "$1" ] && [ -n "$(lcli getpeerlist | grep $1)" ]
}

is_node_connected() {
  [ -n "$1" ] && [ -n "$(lcli getconnectedpeers | grep $1)" ]
}

finish() {
  if [ "$?" -ne 0 ]; then printf "Failed with exit code $?"; templ fail && exit 1; fi
}

###############################################################################
# Script
###############################################################################

trap finish EXIT

if [ -z "$(pgrep bitcoind)" ]; then echo "Bitcoind is not running!" && exit 1; fi

templ banner "Lightning Core Configuration"

## Create any missing paths.
if [ ! -d "$DATA_PATH" ]; then mkdir -p "$DATA_PATH"; fi

## Start lightning daemon.
sh -c $LIB_PATH/start/lightning/lightningd-start.sh

## Start CL-REST Server
#sh -c $LIB_PATH/start/lightning/cl-rest-start.sh

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
# Plugins
###############################################################################

## Enable plugins
if [ -d "$PLUG_PATH" ]; then
  plugins=`find $PLUG_PATH -maxdepth 1 -type d`
  if [ -n "$plugins" ]; then
    echo && printf "Plugins:\n"
    for plugin in $plugins; do
      name=$(basename $plugin)
      if case $name in .*) ;; *) false;; esac; then continue; fi
      if [ -e "$plugin/$name.py" ]; then
        printf "$IND Enabling $name plugin"
        chmod +x $PLUG_PATH/$name/$name.py
        lightning-cli plugin start $PLUG_PATH/$name/$name.py > /dev/null 2>&1
        templ ok
      fi
    done
  fi
fi

###############################################################################
# Peer Connection
###############################################################################

if [ -n "$PEER_LIST" ]; then
  for peer in $(printf $PEER_LIST | tr ',' ' '); do
    
    ## Search for peer file in peers path.
    echo && printf "Checking connection to $peer:"
    config=`find "$SHARE_PATH/$peer"* -name lightning-peer.conf`

    ## Exit out if peer file is not found.
    if [ ! -e "$config" ]; then templ fail && continue; fi

    ## Parse current peering info.
    onion_host=`cat $config | kgrep ONION_NAME`
    node_id="$(cat $config | kgrep NODE_ID)"
    if [ -n "$(pgrep tor)" ] && [ -n "$onion_host" ]; then
      peer_host="$onion_host"
    else
      peer_host="$(cat $config | kgrep HOST_NAME)"
    fi

    ## If valid peer, then connect to node.
    if ! is_node_configured $node_id; then
      printf "\n$IND Adding node: $(prevstr $node_id)@$(prevstr -l 20 $peer_host)"
      lightning-cli connect "$node_id@$peer_host" > /dev/null 2>&1
      printf "\n$IND Connecting to node"
    fi

    while ! is_node_connected $node_id; do sleep 1 && printf "."; done; templ conn

  done
fi
