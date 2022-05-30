#!/usr/bin/env bash
## Start script for bitcoind.

set -E

. $LIBPATH/util/math.sh
. $LIBPATH/util/peers.sh
. $LIBPATH/util/timers.sh
. $LIBPATH/util/wallet.sh

###############################################################################
# Environment
###############################################################################

DATA_PATH="/data/bitcoin"
PEER_PATH="$SHAREPATH/$HOSTNAME"

FUND_FNAME="wallet.conf"
PEER_FNAME="bitcoin-peer.conf"

FUND_FILE="$DATA_PATH/$FUND_FNAME"
PEER_FILE="$PEER_PATH/$PEER_FNAME"

DEFAULT_WALLET="Master"
DEFAULT_LABEL="Coinbase"
DEFAULT_MIN_FEE=0.00001

DEFAULT_PEER_TIMEOUT=10
DEFAULT_TOR_TIMEOUT=20

DEFAULT_MIN_BLOCKS=150
DEFAULT_BLOCK_TIMEOUT=30

###############################################################################
# Methods
###############################################################################

incomplete_chain() {
  [ "$(bitcoin-cli getblockchaininfo | jgrep initialblockdownload)" = "true" ]
}

new_blockchain() {
  chainwork=`bitcoin-cli getblockchaininfo | jgrep chainwork` && [ "$((chainwork + 0))" -lt 3 ]
}

###############################################################################
# Script
###############################################################################

templ banner "Bitcoin Core Configuration"

## Configure default values.
if [ -z "$FUND_WALLET" ]; then FUND_WALLET=$DEFAULT_WALLET; fi
if [ -z "$FUND_LABEL" ];  then FUND_LABEL=$DEFAULT_LABEL; fi
if [ -z "$MIN_FEE" ];     then MIN_FEE=$DEFAULT_MIN_FEE; fi

## Create any missing paths.
if [ ! -d "$DATA_PATH" ]; then mkdir -p "$DATA_PATH"; fi

## Start bitcoin daemon.
$LIBPATH/start/bitcoin/bitcoind-start.sh

## Update share configuration.
$LIBPATH/share/bitcoin-share-config.sh

###############################################################################
# Wallet Configuration
###############################################################################

## If wallet not configured, load / create it.
echo && printf "Loading wallet:\n"
if ! is_wallet_loaded $FUND_WALLET; then
  if ! is_wallet_created $FUND_WALLET; then
    printf "$IND Creating new wallet ...\n"
    bitcoin-cli createwallet $FUND_WALLET > /dev/null 2>&1
  else
    bitcoin-cli loadwallet $FUND_WALLET > /dev/null 2>&1
  fi
fi

## Check if wallet is loaded.
if is_wallet_loaded $FUND_WALLET; then 
  printf "$IND $FUND_WALLET wallet loaded.\n"
else 
  templ fail && exit 1
fi

## Check that tx fee is set.
txfee=`bitcoin-cli getwalletinfo | jgrep paytxfee`
if ! greater_than $txfee $MIN_FEE; then
  printf "$IND Minimum txfee not set! Setting to $MIN_FEE fee.\n"
  bitcoin-cli settxfee $MIN_FEE > /dev/null 2>&1
fi

## If payment address not configured, create it.
if [ ! -e "$FUND_FILE" ]; then
  printf "$IND Generating new $FUND_LABEL payment address ...\n"
  if ! is_address_created $FUND_LABEL $FUND_WALLET; then create_address $FUND_LABEL $FUND_WALLET; fi
  fund_address=`get_address $FUND_LABEL $FUND_WALLET`
  printf "WALLET_NAME=$FUND_WALLET\nLABEL=$ADDR_LABEL\nADDRESS=$fund_address\n" > $FUND_FILE
fi

## Check that payment address is configured.
address=`cat $FUND_FILE | kgrep ADDRESS`
if [ -n "$address" ]; then
  printf "$IND $FUND_LABEL address: $address" && templ ok
else
  templ fail && exit 1
fi

###############################################################################
# Peer Connection
###############################################################################

[ -z $PEER_TIMEOUT ]  && PEER_TIMEOUT=$DEFAULT_PEER_TIMEOUT
[ -z $TOR_TIMEOUT ]   && TOR_TIMEOUT=$DEFAULT_TOR_TIMEOUT

[ -n "$(pgrep tor)" ] \
  && CONN_TIMEOUT=$TOR_TIMEOUT \
  || CONN_TIMEOUT=$PEER_TIMEOUT

if ( [ -n "$PEER_LIST" ] || [ -n "$CHAN_LIST" ] || [ -n "$USE_FAUCET" ] ); then
  for peer in $(printf $PEER_LIST $CHAN_LIST $USE_FAUCET | tr ',' ' '); do
    
    ## Search for peer file in peers path.
    echo && printf "Checking connection to $peer: "
    config=`get_peer_config $peer $PEER_FNAME`

    ## Exit out if peer file is not found.
    if [ ! -e "$config" ]; then templ fail && continue; fi

    ## Parse current peering info.
    onion_host=`cat $config | kgrep ONION_NAME`
    if [ -z "$LOCAL_ONLY" ] && [ -n "$(pgrep tor)" ] && [ -n "$onion_host" ]; then
      peer_host="$onion_host"
    else
      peer_host="$(cat $config | kgrep HOST_NAME)"
    fi
    
    ## Try to ping host first
    ## If valid peer, then connect to node.
    if ! is_peer_configured $peer_host; then
      printf "\n$IND Adding node: $(prevstr -l 20 $peer_host)"
      bitcoin-cli addnode "$peer_host" add
      printf "\n$IND Connecting to node "
    fi
    
    ( ## Start a process to connect to peer (with a timeout).
      while ! is_peer_connected $peer_host; do 
        sleep 1 && printf "."; 
      done 
    ) & timeout_child $CONN_TIMEOUT
    
    ## Check if we connected or timed out.
    ( [ $? -eq 0 ] && templ conn ) || templ tout

  done

fi

###############################################################################
# Blockchain Config
###############################################################################

if [ -z "$MIN_BLOCKS" ];    then MIN_BLOCKS=$DEFAULT_MIN_BLOCKS; fi
if [ -z "$BLOCK_TIMEOUT" ]; then BLOCK_TIMEOUT=$DEFAULT_BLOCK_TIMEOUT; fi

echo && printf "Blockchain state: "
if incomplete_chain; then
  ## Blockchain download is incomplete.
  if ! new_blockchain; then
    ## Previous chain exists on disk.
    printf "$(templ hlight 'CONNECTING' 255 220)"
    if get_peer_count; then
      ## Connected to existing peers on the network.
      printf "\n$IND Waiting (up to ${BLOCK_TIMEOUT}s) for blockchain to sync with peers ."
      ( while get_ibd_state; do sleep 2 && printf "."; done ) & timeout_child $BLOCK_TIMEOUT
      if incomplete_chain; then printf "timed out!" && templ skip && exit 2; else templ ok; fi
    elif [ -n "$PEER_LIST" ]; then
      ## Unable to connect to any peers.
      printf "\n$IND Failed to connect to any peers!" && templ fail && exit 1
    else
      ## No peers are available to sync.
      printf "\n$IND No peers available to connect!" && templ skip
    fi
  elif [ -n "$MINE_NODE" ]; then
    ## Check how many blocks we need to initialize the chain.
    printf "$(templ hlight 'BUILDING' 255 055)"
    printf "\n$IND Checking block height:"
    blocks=`bitcoin-cli getblockcount`
    if [ "$((blocks))" -lt "$((MIN_BLOCKS))" ]; then
      ## Block height is too low, must generate blocks..
      block_amt="$((MIN_BLOCKS - blocks))"
      address=`cat $FUND_FILE | kgrep ADDRESS`
      printf "\n$IND Block height is too low!"
      printf "\n$IND Coinbase address: $address"
      bitcoin-cli generatetoaddress $block_amt $address > /dev/null 2>&1
      printf "\n$IND Generated $block_amt blocks" && templ ok
    else
      printf "\n$IND Blockchain already initialized!" && templ skip
    fi
  else
    printf "$(templ hlight 'NOT INITIALIZED' 255 160)"
    printf "\n$IND No miners or peers available to bootstrap the blockchain!"
    printf "\n$IND You must specify a peer, or add a miner to this node." && templ fail && exit 1
  fi
else
  printf "$(templ hlight 'SYNCHRONIZED' 255 033)" && templ ok
fi

if [ -n "$MINE_NODE" ]; then
  ## Set the mining configuration, if specified.
  if [ "$MINE_NODE" != "DEFAULT" ]; then schedule="--schedule=$MINE_NODE"; fi
  ## Run regminer if not already running.
  echo && miner_pid="$(regminer --check)"
  if [ -z "$miner_pid" ]; then 
    address=`cat $FUND_FILE | kgrep ADDRESS`
    regminer $schedule $address
  else
    printf "Miner process running at PID: $(templ hlight "$miner_pid")" && templ ok
  fi
fi
