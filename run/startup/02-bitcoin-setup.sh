#!/usr/bin/env bash
## Start script for bitcoind.

set -E

###############################################################################
# Environment
###############################################################################

DATA_PATH="/data/bitcoin"
PEER_PATH="$SHAREPATH/$HOSTNAME"

FUND_FILE="$DATA_PATH/wallet.conf"
PEER_FILE="$PEER_PATH/bitcoin-peer.conf"

DEFAULT_WALLET="master"
DEFAULT_LABEL="coinbase"
DEFAULT_MIN_FEE=0.00001
DEFAULT_MIN_BLOCKS=150

BLOCK_SYNC_TIMEOUT=30

###############################################################################
# Methods
###############################################################################

is_peer_configured() {
  [ -n "$1" ] && [ -n "$(bitcoin-cli getaddednodeinfo | jgrep addednode | grep $1)" ]
}

is_peer_connected() {
  [ -n "$1" ] && [ "$(bitcoin-cli getaddednodeinfo $1 2>&1 | jgrep connected | head -n 1)" = "true" ]
}

get_peer_config() {
  [ -n "$1" ] && find "$SHAREPATH/$1"* -name $PEER_FILE
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

finish() {
  if [ "$?" -ne 0 ]; then printf "Failed with exit code $?"; templ fail && exit 1; fi
}

###############################################################################
# Script
###############################################################################

trap finish EXIT

if [ "$?" -ne 0 ]; then exit 1; fi

templ banner "Bitcoin Core Configuration"

## Configure default values.
if [ -z "$FUND_WALLET" ]; then FUND_WALLET=$DEFAULT_WALLET; fi
if [ -z "$FUND_LABEL" ]; then FUND_LABEL=$DEFAULT_LABEL; fi
if [ -z "$MIN_FEE" ]; then MIN_FEE=$DEFAULT_MIN_FEE; fi
if [ -z "$MIN_BLOCKS" ]; then MIN_BLOCKS=$DEFAULT_MIN_BLOCKS; fi

## Create any missing paths.
if [ ! -d "$DATA_PATH" ]; then mkdir -p "$DATA_PATH"; fi

## Start bitcoin daemon.
sh -c $LIBPATH/start/bitcoin/bitcoind-start.sh

## Update share configuration.
sh -c $LIBPATH/share/bitcoin-share-config.sh

###############################################################################
# Wallet Configuration
###############################################################################

## Make sure that wallet is loaded.
echo && printf "Loading $FUND_WALLET wallet:"
if ! is_wallet_loaded; then
  if ! is_wallet_created $FUND_WALLET; then
    printf "\n$IND Creating new wallet."
    bitcoin-cli createwallet $FUND_WALLET > /dev/null 2>&1
  else
    bitcoin-cli loadwallet $FUND_WALLET > /dev/null 2>&1
  fi
fi

## Check that tx fee is set.
txfee=`bitcoin-cli getwalletinfo | jgrep paytxfee`
if ! greater_than $txfee $MIN_FEE; then
  printf "\n$IND Minimum txfee not set! Setting to $MIN_FEE fee."
  bitcoin-cli settxfee $MIN_FEE > /dev/null 2>&1
fi

## Check that payment address is configured.
if [ ! -e "$FUND_FILE" ]; then
  printf "\n$IND Generating new $FUND_LABEL payment address."
  if ! is_address_created $FUND_LABEL; then create_address_by_label $FUND_LABEL; fi
  fund_address=`get_address_by_label $FUND_LABEL`
  printf %b\\n "WALLET_NAME=$FUND_WALLET\nLABEL=$ADDR_LABEL\nADDRESS=$fund_address" > $FUND_FILE
fi

templ ok

###############################################################################
# Peer Connection
###############################################################################

if [ -n "$PEER_LIST" ]; then
  for peer in $(printf "$PEER_LIST" | tr ',' ' '); do
    
    ## Search for peer file in peers path.
    echo && printf "Checking connection to $peer: "
    config=`find $SHAREPATH/$peer* -name bitcoin-peer.conf`

    ## Exit out if peer file is not found.
    if [ ! -e "$config" ]; then templ fail && continue; fi

    ## Parse current peering info.
    onion_host=`cat $config | kgrep ONION_NAME`
    if [ -n "$(pgrep tor)" ] && [ -n "$onion_host" ]; then
      peer_host="$onion_host"
    else
      peer_host="$(cat $config | kgrep HOST_NAME)"
    fi
    
    ## If valid peer, then connect to node.
    if ! is_peer_configured $peer_host; then
      printf "\n$IND Adding node: $(prevstr -l 20 $peer_host)"
      bitcoin-cli addnode "$peer_host" add
      printf "\n$IND Connecting to node "
    fi
    
    while ! is_peer_connected $peer_host; do sleep 1 && printf "."; done; templ conn

  done

fi

###############################################################################
# Blockchain Config
###############################################################################

## Wait for blockchain to sync with peers.
if [ "$((peer_connections))" -ne 0 ] && get_ibd_state; then
  echo && printf "Waiting (up to ${BLOCK_SYNC_TIMEOUT}s) for blockchain to sync with peers ."
  ( while get_ibd_state; do sleep 2 && printf "."; done ) & timeout_child $BLOCK_SYNC_TIMEOUT
  templ ok
fi

if [ -n "$SEED_NODE" ]; then
  ## Check if variable specifies an amount of blocks.
  if [ "$((SEED_NODE))" -gt 1 ]; then MIN_BLOCKS=$SEED_NODE; fi

  ## Check if current block height meets the minimum.
  blocks=`bitcoin-cli getblockcount`
  address=`cat $FUND_FILE | kgrep ADDRESS`
  if [ "$((blocks))" -lt "$((MIN_BLOCKS))" ]; then
    block_amt="$((MIN_BLOCKS - blocks))"
    printf "Mining $block_amt blocks to address $address"
    bitcoin-cli generatetoaddress $block_amt $address > /dev/null 2>&1
    templ ok
  fi
fi

if [ -n "$MINE_NODE" ]; then
  address=`cat $FUND_FILE | kgrep ADDRESS`
  ## Check if a mining schedule is specified.
  if [ "$MINE_NODE" != "DEFAULT" ]; then schedule="--schedule=$MINE_NODE"; fi
  ## Run regminer if not already running.
  if [ -n "$(regminer --check)" ]; then regminer --kill; fi
  echo && regminer $schedule $address
fi

echo && chainstatus="$(bitcoin-cli -getinfo | grep 100.0000%)"
if [ -n "$chainstatus" ]; then 
  printf %s "Blockchain $chainstatus"; templ ok
else 
  printf "Failed to sync blockchain with network!"; templ fail && exit 1
fi
