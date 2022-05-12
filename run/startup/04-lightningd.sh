#!/bin/sh
## Start script for lightning daemon.

. $ENV_FILE && set -E

###############################################################################
# Environment
###############################################################################

DATA_PATH="/data/lightning"
CONF_PATH="/root/.lightning"
LOG_PATH="/var/log/lightningd.log"

DEFAULT_CLN_ONION_HOST="/data/tor/services/cln-peer/hostname"
DEFAULT_CLN_PEER_PORT=3001

PEER_FILE="cln-peer.conf"
ADDR_FILE="fund.address"

###############################################################################
# Methods
###############################################################################

is_node_connected() {
  [ -n "$1" ] && [ -n "$(lightning-cli listpeers | jgrep id | grep $1)" ]
}

###############################################################################
# Script
###############################################################################

## Set defaults.
if [ -z "$CLN_ONION_HOST" ]; then CLN_ONION_HOST=$DEFAULT_CLN_ONION_HOST; fi
if [ -z "$CLN_PEER_PORT" ]; then CLN_PEER_PORT=$DEFAULT_CLN_PEER_PORT; fi

## If share folder mounted, enable peering.
if [ -n "$SHARE_PATH" ] && [ -d "$SHARE_PATH" ]; then PEERING=1; fi

## Check for existing process.
DAEMON_PID=`pgrep lightningd`

if [ -z "$DAEMON_PID" ]; then

  printf "
=============================================================================
  Starting Lightning Daemon
=============================================================================
  \n"
  
  ## Create data directory if does not exist.
  if [ ! -d "$DATA_PATH" ]; then 
    echo "Adding persistent data directory for lightning daemon  ..."
    mkdir -p $DATA_PATH
  fi

  # ## Symlink the path for the bitcoin interface to persistent storage.
  # if [ ! -e "$CONF_PATH/bitcoin" ]; then
  #   echo "Adding symlink for bitcoin network RPC ..."
  #   ln -s $DATA_PATH/bitcoin $CONF_PATH/bitcoin
  # fi

  ## Symlink the path for the bitcoin interface to persistent storage.
  if [ ! -e "$CONF_PATH/regtest" ]; then
    echo "Adding symlink for regtest network RPC ..."
    ln -s $DATA_PATH/regtest $CONF_PATH/regtest
  fi

  ## Start lightning in daemon mode.
  lightningd --daemon --conf=$CONF_PATH/config

  ## Wait for lightningd to load.
  tail -f $LOG_PATH | while read line; do
    echo "$line" && echo "$line" | grep "Server started with public key"
    if [ $? = 0 ]; then echo "Lightning daemon running on regtest network!" && exit 0; fi
  done

else echo "Lightning daemon is running under PID: $DAEMON_PID"; fi

###############################################################################
# Payment Configuration
###############################################################################

## Generate a funding address.
address_file=`cat $DATA_PATH/$ADDR_FILE`
if [ -z "$address_file" ]; then
  printf "Generating new payment address for lightning ... "
  lightning-cli newaddr | jgrep bech32 > $DATA_PATH/$ADDR_FILE
  printf %b\\n " done."
fi

## Configure channel settings.
lightning-cli funderupdate match > /dev/null 2>&1

###############################################################################
# Share Configuration
###############################################################################

node_info=`lightning-cli getinfo`
if [ -n "$PEERING" ] && [ -n "$node_info" ]; then
  printf "Generating cln-peer.conf ... "
  printf "## C-Lightning Node Configuration
PEER_HOST=$(cat $CLN_ONION_HOST || printf $HOSTNAME)
PEER_PORT=$CLN_PEER_PORT
NODE_ID=$(printf "$node_info" | jgrep id)
NODE_ALIAS=$(printf "$node_info" | jgrep alias)
NODE_COLOR=$(printf "$node_info" | jgrep color)
" > $SHARE_PATH/$HOSTNAME/$PEER_FILE
  printf %b\\n "done."
fi

###############################################################################
# Peer Connection
###############################################################################

if [ -n "$PEERING" ] && [ -n "$ADD_PEERS" ]; then
  for peer in "$(printf $ADD_PEERS | tr ',' '\n')"; do
    
    ## Search for peer file in peers path.
    printf "Searching for node file from $peer ... "
    peer_conf=`find $SHARE_PATH/$peer* -name $PEER_FILE` > /dev/null 2>&1

    ## Exit out if peer file is not found.
    if [ ! -e "$peer_conf" ]; then 
      printf %b\\n "failed to locate $PEER_FILE for $peer." && continue
    else 
      printf %b\\n "done."
    fi

    ## Fetch current peering info.
    peer_host="$(cat $peer_conf | kgrep PEER_HOST)"
    peer_port="$(cat $peer_conf | kgrep PEER_PORT)"
    node_id="$(cat $peer_conf | kgrep NODE_ID)"

    ## If valid peer, then connect to node.
    if ! is_node_connected $node_id; then
      printf "Peering to $peer lightning node: $node_id ... "
      lightning-cli connect "$node_id@$peer_host" > /dev/null
      printf %b\\n "done."
    fi

  done;
fi;
