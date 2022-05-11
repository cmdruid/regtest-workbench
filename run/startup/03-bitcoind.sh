#!/bin/sh
## Start script for bitcoind.

. $ENV_FILE && set -E

###############################################################################
# Environment
###############################################################################

DATA_PATH="/data/bitcoin"
BITCOIND_LOG="/var/log/bitcoin/debug.log"
BLOCK_SYNC_TIMEOUT=30

CONF_FILE="/root/.bitcoin/bitcoin.conf"
CRED_FILE="$DATA_PATH/credentials.conf"
PEER_FILE="btc-peer.conf"
RPC_FILE="btc-rpc.conf"

DEFAULT_BTC_ONION_HOST="/data/tor/services/btc-peer/hostname"
DEFAULT_BTC_ONION_PORT=18445
DEFAULT_BTC_PEER_PORT=18444

DEFAULT_RPC_ONION_HOST="/data/tor/services/btc-rpc/hostname"
DEFAULT_RPC_SOCK=18446
DEFAULT_RPC_PORT=18443

DEFAULT_WALLET="master"
DEFAULT_LABEL="coinbase"
DEFAULT_MIN_FEE=0.00001
DEFAULT_MIN_BLOCKS=101

###############################################################################
# Methods
###############################################################################

check_config() {
  if [ -n "$1" ] && ! grep "$1" $CONF_FILE; then printf %b\\n "$1" >> $CONF_FILE 2>&1; fi
}

gen_peer_conf() {
  peer_host=`cat $BTC_ONION_HOST || printf $HOSTNAME`
  base_conf="## Peer Configuration\nPEER_HOST=$peer_host"
  if [ -n "$(printf "$peer_host" | grep .onion)" ]; then
    peer_conf="$base_conf\nPEER_PORT=$BTC_ONION_PORT"
  else
    peer_conf="$base_conf\nPEER_PORT=$BTC_PEER_PORT"
  fi
  printf %b\\n "$peer_conf" > $SHARE_PATH/$HOSTNAME/$PEER_FILE
}

gen_rpc_conf() {
  rpc_host=`cat $RPC_ONION_HOST || printf $HOSTNAME`
  rpc_user=`cat $CRED_FILE | grep rpcuser`
  rpc_pass=`cat $CRED_FILE | grep rpcpassword`
  base_conf="## RPC Configuration\n$rpc_user\n$rpc_pass"
  if [ -n "$(printf "$rpc_host" | grep .onion)" ]; then
    rpc_conf="$base_conf\nrpcconnect=127.0.0.1\nrpcport=$RPC_SOCK\n#rpconion=$rpc_host:$RPC_PORT"
  else
    rpc_conf="$base_conf\nrpcconnect=$rpc_host\nrpcport=$RPC_PORT"
  fi
  printf %b\\n "$rpc_conf" > $SHARE_PATH/$HOSTNAME/$RPC_FILE
}

is_peer_connected() {
  [ -n "$1" ] && [ -n "$(bitcoin-cli getaddednodeinfo | jgrep addednode | grep $1)" ]
}

get_peer_config() {
  [ -n "$1" ] && find "$SHARE_PATH/$1"* -name $PEER_FILE
}

is_wallet_loaded() {
  [ -n "$(bitcoin-cli listwallets | grep $BTC_WALLET)" ]
}

is_wallet_created() {
  [ -n "$(bitcoin-cli listwalletdir | jgrep name | grep $BTC_WALLET)" ]
}

is_address_created() {
  if [ -n "$2" ]; then wallet="$2"; else wallet="$BTC_WALLET"; fi
  [ -n "$1" ] && bitcoin-cli -rpcwallet=$wallet listlabels | grep $1 > /dev/null 2>&1
}

load_wallet() {
  if ! is_wallet_created $BTC_WALLET; then
    printf "No existing $BTC_WALLET wallet found, creating ..." >&2
    bitcoin-cli createwallet $BTC_WALLET > /dev/null && printf "done.\n"
  else
    printf "Loading existing wallet $BTC_WALLET ... " >&2
    bitcoin-cli loadwallet $BTC_WALLET > /dev/null && printf "done.\n"
  fi
}

create_address_by_label() {
  if [ -n "$2" ]; then wallet="$2"; else wallet="$BTC_WALLET"; fi
  [ -n "$1" ] && bitcoin-cli -rpcwallet=$wallet getnewaddress $1 > /dev/null 2>&1
}

get_address_by_label() {
  if [ -n "$2" ]; then wallet="$2"; else wallet="$BTC_WALLET"; fi
  [ -n "$1" ] && bitcoin-cli -rpcwallet=$wallet getaddressesbylabel $1 | \
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
  ( sleep $timeout && if ps | grep $child; then kill $child && printf "$msg"; fi ) &
  wait $child 2>/dev/null
}

###############################################################################
# Script
###############################################################################

## Configure default values.
if [ -z "$BTC_ONION_HOST" ]; then BTC_ONION_HOST=$DEFAULT_BTC_ONION_HOST; fi
if [ -z "$BTC_ONION_PORT" ]; then BTC_ONION_PORT=$DEFAULT_BTC_ONION_PORT; fi
if [ -z "$BTC_PEER_PORT" ]; then BTC_PEER_PORT=$DEFAULT_BTC_PEER_PORT; fi
if [ -z "$RPC_ONION_HOST" ]; then RPC_ONION_HOST=$DEFAULT_RPC_ONION_HOST; fi
if [ -z "$RPC_SOCK" ]; then RPC_SOCK=$DEFAULT_RPC_SOCK; fi
if [ -z "$RPC_PORT" ]; then RPC_PORT=$DEFAULT_RPC_PORT; fi
if [ -z "$BTC_WALLET" ]; then BTC_WALLET=$DEFAULT_WALLET; fi
if [ -z "$ADDR_LABEL" ]; then ADDR_LABEL=$DEFAULT_LABEL; fi
if [ -z "$MIN_FEE" ]; then MIN_FEE=$DEFAULT_MIN_FEE; fi
if [ -z "$MIN_BLOCKS" ]; then MIN_BLOCKS=$DEFAULT_MIN_BLOCKS; fi

## If share folder mounted, enable peering.
if [ -n "$SHARE_PATH" ] && [ -d "$SHARE_PATH" ]; then PEERING=1; fi

## Get PID of existing daemon.
DAEMON_PID=`pgrep bitcoind`

if [ -z "$DAEMON_PID" ]; then

  printf "
=============================================================================
  Starting Bitcoin Daemon
=============================================================================
  \n"

  ## If missing, create bitcoin data path.
  if [ ! -d "$DATA_PATH" ]; then
    echo "Adding bitcoind data directories ..."
    mkdir "$DATA_PATH"
  fi

  ## If missing, generate rpcauth credentials.
  if [ ! -e "$DATA_PATH/rpcauth.conf" ]; then
    printf %b\\n "Generating RPC credentials ... "
    rpcauth --save="$DATA_PATH"
    check_config "includeconf=$DATA_PATH/rpcauth.conf"
    printf %b\\n "done."
  fi

  ## If missing, generate externalip.conf.
  if [ ! -e "$DATA_PATH/externalip.conf" ]; then
    printf "Generating external IP configuration ... "
    peer_host=`cat $BTC_ONION_HOST || printf $HOSTNAME`
    printf %b\\n "externalip=$peer_host" > "$DATA_PATH/externalip.conf"
    check_config "includeconf=$DATA_PATH/externalip.conf"
    printf %b\\n "done."
  fi

  ## If seed node, disable searching for peers.
  if [ -n "$SEED_NODE" ]; then check_config "regtest.connect=0"; fi

  ## Start bitcoind then tail the logfile to search for the completion phrase.
  echo "Starting bitcoin daemon ..."
  bitcoind; tail -f $BITCOIND_LOG | while read line; do
    echo "$line" && echo "$line" | grep "init message: Done loading"
    if [ $? = 0 ]; then echo "Bitcoin daemon initialized!" && exit 0; fi
  done

else echo "Bitcoin daemon is running under PID: $DAEMON_PID"; fi

###############################################################################
# Share Configuration
###############################################################################

if [ -n "$PEERING" ]; then
  printf "Generating btc-peer.conf ... " && gen_peer_conf && printf %b\\n "done."
  printf "Generating btc-rpc.conf ... " && gen_rpc_conf && printf %b\\n "done."
fi

###############################################################################
# Peer Connection
###############################################################################

if [ -n "$PEERING" ] && [ -n "$ADD_PEERS" ]; then
  for peer in "$(printf $ADD_PEERS | tr ',' '\n')"; do
    
    ## Search for peer file in peers path.
    printf "Searching for peer file from $peer ... "
    peer_conf=`get_peer_config $peer`

    ## Exit out if peer file is not found.
    if [ ! -e "$peer_conf" ]; then 
      printf %b\\n "failed to locate $PEER_FILE for $peer." && continue
    else 
      printf %b\\n "done."
    fi

    ## Fetch current peering info.
    peer_host="$(cat $peer_conf | kgrep PEER_HOST)"
    peer_port="$(cat $peer_conf | kgrep PEER_PORT)"

    ## If valid peer, then connect to node.
    if ! is_peer_connected $peer_host; then
      printf "Peering to $peer bitcoin node: $peer_host ... "
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
wallet_conf="$DATA_PATH/wallet.conf"
printf "Saving wallet configuration to $wallet_conf ... "
if ! is_address_created $ADDR_LABEL; then create_address_by_label $ADDR_LABEL; fi
recv_address=`get_address_by_label $ADDR_LABEL`
printf "## Wallet Configuration
WALLET_NAME=$BTC_WALLET
ADDR_LABEL=$ADDR_LABEL
RECV_ADDRESS=$recv_address
" > $wallet_conf
printf %b\\n "done."

###############################################################################
# Blockchain Config
###############################################################################

if [ -n "$SEED_NODE" ]; then

  ## Check if current block height meets the minimum.
  blocks=`bitcoin-cli getblockcount`
  if [ "$((blocks))" -lt "$((MIN_BLOCKS))" ]; then
    block_amt="$((MIN_BLOCKS - blocks))"
    printf "Mining $block_amt blocks to address $recv_address ... "
    bitcoin-cli generatetoaddress $block_amt $recv_address > /dev/null 2>&1
    printf %b\\n "done."
  fi

  ## Run regminer if not already running.
  if [ -z "$(regminer --check)" ]; then regminer $recv_address; fi

else

  ## Wait for blockchain to sync with peers.
  peer_connections=`bitcoin-cli getaddednodeinfo | jgrep addednode | wc -l`
  if [ "$peer_connections" -ne 0 ] && get_ibd_state; then
    printf "Waiting (up to ${BLOCK_SYNC_TIMEOUT}s) for blockchain to sync with peers ."
    ( while get_ibd_state; do sleep 2 && printf "."; done ) & timeout_child $BLOCK_SYNC_TIMEOUT
    printf %b\\n " done."
  fi
  
fi
