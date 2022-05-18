#!/bin/sh
## Start script for bitcoind.

set -E

###############################################################################
# Environment
###############################################################################

DATA_PATH="/data/bitcoin"
CONF_PATH="$HOME/config/bitcoin"
LINK_PATH="$HOME/.bitcoin"
PEER_PATH="$SHARE_PATH/$HOSTNAME"
LOGS_PATH="/var/log/bitcoin"

CONF_FILE="$CONF_PATH/bitcoin.conf"
LINK_FILE="$LINK_PATH/bitcoin.conf"
AUTH_FILE="$DATA_PATH/rpcauth.conf"
FUND_FILE="$DATA_PATH/wallet.conf"
PEER_FILE="$PEER_PATH/bitcoin-peer.conf"
LOGS_FILE="$LOGS_PATH/debug.log"

DEFAULT_WALLET="master"
DEFAULT_LABEL="coinbase"
DEFAULT_MIN_FEE=0.00001
DEFAULT_MIN_BLOCKS=150

BLOCK_SYNC_TIMEOUT=30

###############################################################################
# Methods
###############################################################################

is_peer_connected() {
  [ -n "$1" ] && [ -n "$(bitcoin-cli getaddednodeinfo | jgrep addednode | grep $1)" ]
}

get_peer_config() {
  [ -n "$1" ] && find "$SHARE_PATH/$1"* -name $PEER_FILE
}

is_wallet_loaded() {
  [ -n "$(bitcoin-cli listwallets | grep $FUND_WALLET)" ]
}

is_wallet_created() {
  [ -n "$(bitcoin-cli listwalletdir | jgrep name | grep $FUND_WALLET)" ]
}

is_address_created() {
  [ -n "$1" ] && bitcoin-cli -rpcwallet=$FUND_WALLET listlabels | grep $2 > /dev/null 2>&1
}

load_wallet() {
  if ! is_wallet_created $FUND_WALLET; then
    printf "No existing $FUND_WALLET wallet found, creating ..." >&2
    bitcoin-cli createwallet $FUND_WALLET > /dev/null && printf "done.\n"
  else
    printf "Loading existing wallet $FUND_WALLET ... " >&2
    bitcoin-cli loadwallet $FUND_WALLET > /dev/null && printf "done.\n"
  fi
}

create_address_by_label() {
  [ -n "$1" ] && bitcoin-cli -rpcwallet=$FUND_WALLET getnewaddress $1 > /dev/null 2>&1
}

get_address_by_label() {
  [ -n "$1" ] && bitcoin-cli -rpcwallet=$FUND_WALLET getaddressesbylabel $1 | \
  grep -E 'bc[[:alnum:]]{42}' | tr '":{' ' ' | awk '{$1=$1};1'
}

greater_than() {
  [ -n "$1" ] && [ -n "$2" ] && \
  [ -n "$(echo "$1 $2" | awk '{ print ($1>=$2) }' | grep 1)" ]
}

get_ibd_state() {
  state=`bitcoin-cli getblockchaininfo | jgrep initialblockdownload`
  [ "$state" = "true" ]
}

timeout_child() {
  trap -- "" TERM
  child=$!
  timeout=$1
  msg=" timed out after $1 seconds.\n"
  ( sleep $timeout; if ps | grep $child > /dev/null; then kill $child && printf "$msg"; fi ) &
  wait $child 2>/dev/null
}

###############################################################################
# Script
###############################################################################

printf "
=============================================================================
  Core Bitcoin Configuration
=============================================================================
\n"

## Configure default values.
if [ -z "$FUND_WALLET" ]; then FUND_WALLET=$DEFAULT_WALLET; fi
if [ -z "$FUND_LABEL" ]; then FUND_LABEL=$DEFAULT_LABEL; fi
if [ -z "$MIN_FEE" ]; then MIN_FEE=$DEFAULT_MIN_FEE; fi
if [ -z "$MIN_BLOCKS" ]; then MIN_BLOCKS=$DEFAULT_MIN_BLOCKS; fi

## Create any missing paths.
if [ ! -d "$DATA_PATH" ]; then mkdir -p "$DATA_PATH"; fi
if [ ! -d "$LINK_PATH" ]; then mkdir -p "$LINK_PATH"; fi
if [ ! -d "$LOGS_PATH" ]; then mkdir -p "$LOGS_PATH"; fi

## Make sure configuration file is linked.
if [ ! -e "$LINK_FILE" ]; then
  printf "Adding symlink for $LINK_FILE ... "
  ln -s $CONF_FILE $LINK_FILE
  printf %b\\n "done."
fi

## Get PID of existing daemon.
DAEMON_PID=`pgrep bitcoind`

if [ -z "$DAEMON_PID" ]; then

  ## Declare base config string.
  config=""

  ## Add rpcauth credentials.
  if [ ! -e "$AUTH_FILE" ]; then
    printf "Generating RPC credentials ... "
    rpcauth --save="$DATA_PATH"
    config="$config -$(cat $AUTH_FILE)"
    printf %b\\n "done."
  fi

  ## If tor is running, add tor configuration.
  if [ -n "$(pgrep tor)" ]; then
    config="$config -proxy=127.0.0.1:9050"
  fi

  # ## If missing, generate externalip.conf.
  # if [ ! -e "$DATA_PATH/externalip.conf" ]; then
  #   printf "Generating external IP configuration ... "
  #   peer_host=`cat $BTC_ONION_HOST || printf $HOSTNAME`
  #   printf %b\\n "externalip=$peer_host" > "$DATA_PATH/externalip.conf"
  #   check_config "includeconf=$DATA_PATH/externalip.conf"
  #   printf %b\\n "done."
  # fi

  ## Start bitcoind then tail the logfile to search for the completion phrase.
  bitcoind $config; tail -f $LOGS_FILE | while read line; do
    echo "$line" && echo "$line" | grep "init message: Done loading"
    if [ $? = 0 ]; then echo "Bitcoin daemon initialized!" && exit 0; fi
  done

else echo "Bitcoin daemon is running under PID: $DAEMON_PID"; fi

## Update share configuration.
sh -c $WORK_PATH/lib/share/bitcoin-share-config.sh

###############################################################################
# Peer Connection
###############################################################################

if [ -n "$ADD_PEERS" ]; then
  for peer in "$(printf $ADD_PEERS | tr ',' '\n')"; do
    
    ## Search for peer file in peers path.
    printf "Searching for connection settings from $peer ... "
    config=`find $SHARE_PATH/$peer* -name bitcoin-peer.conf`

    ## Exit out if peer file is not found.
    if [ ! -e "$config" ]; then printf %b\\n "failed!" && continue; fi
    printf %b\\n "done."

    ## Parse current peering info.
    onion_host=`cat $config | kgrep ONION_NAME`
    if [ -n "$(pgrep tor)" ] && [ -n "$onion_host" ]; then
      peer_host="$onion_host"
    else
      peer_host="$(cat $config | kgrep HOST_NAME)"
    fi

    ## If valid peer, then connect to node.
    if ! is_peer_connected $peer_host; then
      printf "Peering to bitcoin node $peer_host ... "
      bitcoin-cli addnode "$peer_host" add
      printf %b\\n "done."
    fi

  done

fi

###############################################################################
# Wallet Configuration
###############################################################################

## Make sure that wallet is loaded.
if ! is_wallet_loaded; then load_wallet; fi

## Check that tx fee is set.
txfee=`bitcoin-cli getwalletinfo | jgrep paytxfee`
if ! greater_than $txfee $MIN_FEE; then
  printf "Minimum txfee not set! Setting to $MIN_FEE ... "
  bitcoin-cli settxfee $MIN_FEE > /dev/null 2>&1
  printf %b\\n "done."
fi

## Check that payment address is configured.
if [ ! -e "$FUND_FILE" ]; then
  printf "Configuring $FUND_WALLET wallet ... "
  if ! is_address_created $FUND_LABEL; then create_address_by_label $FUND_LABEL; fi
  fund_address=`get_address_by_label $FUND_LABEL`
  printf %b\\n "WALLET_NAME=$FUND_WALLET\nLABEL=$ADDR_LABEL\nADDRESS=$fund_address" > $FUND_FILE
  printf %b\\n "done."
fi

###############################################################################
# Blockchain Config
###############################################################################

if [ -n "$SEED_NODE" ]; then

  ## Check if current block height meets the minimum.
  blocks=`bitcoin-cli getblockcount`
  address=`cat $FUND_FILE | kgrep ADDRESS`
  if [ "$((blocks))" -lt "$((MIN_BLOCKS))" ]; then
    block_amt="$((MIN_BLOCKS - blocks))"
    printf "Mining $block_amt blocks to address $address ... "
    bitcoin-cli generatetoaddress $block_amt $address > /dev/null 2>&1
    printf %b\\n "done."
  fi

  ## Run regminer if not already running.
  if [ -z "$(regminer --check)" ]; then regminer $address; fi

else

  ## Wait for blockchain to sync with peers.
  peer_connections=`bitcoin-cli getconnectioncount`
  if [ "$peer_connections" -ne 0 ] && get_ibd_state; then
    printf "Waiting (up to ${BLOCK_SYNC_TIMEOUT}s) for blockchain to sync with peers ."
    ( while get_ibd_state; do sleep 2 && printf "."; done ) & timeout_child $BLOCK_SYNC_TIMEOUT
    printf %b\\n " done."
  else 
    printf %b\\n "Blockchain $(bitcoin-cli -getinfo | grep Verification)"
  fi
fi
