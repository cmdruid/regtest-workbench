#!/bin/sh
## Startup script for funding the node.

. $ENV_FILE && set -E

###############################################################################
# Environment
###############################################################################

MIN_FUNDS=0.01

RPC_FILE="btc-rpc.conf"
BTC_WALLET_CONF="/data/bitcoin/wallet.conf"
CLN_WALLET_CONF="/data/lightning/fund.address"

FAUCET_CONF=""
FAUCET_WALLET=""
FAUCET_DELAY=0

###############################################################################
# Methods
###############################################################################

greater_than() {
  [ -n "$1" ] && [ -n "$2" ] && \
  [ -n "$(echo "$1 $2" | awk '{ print ($1>=$2) }' | grep 1)" ]
}

wallet_cli() {
  [ -n "$1" ] && bitcoin-cli -rpcwallet=$1 $@
}

faucet_cli() {
  [ -n "$FAUCET_CONF" ] && [ -n "$FAUCET_WALLET" ] && \
  bitcoin-cli -conf="$FAUCET_CONF" -rpcwallet="$FAUCET_WALLET" $@
}

get_btc_balance() {
  bitcoin-cli getbalance
}

get_cln_balance() {
  total=0
  for value in `lightning-cli listfunds | jgrep value`; do total="$((total + value))"; done
  printf "$((total / 100000000))"
}

###############################################################################
# Script
###############################################################################

if [ -z "$MIN_FUNDS" ]; then MIN_FUNDS=$DEFAULT_MIN_FUNDS; fi

## Fetch details for bitcoin wallet.
wallet_data=`cat $BTC_WALLET_CONF`
wallet_name=`printf "$wallet_data" | kgrep WALLET_NAME`
btc_address=`printf "$wallet_data" | kgrep RECV_ADDRESS`
if [ -z "$btc_address" ]; then echo "Failed to read $BTC_WALLET_CONF" && exit 1; fi

## Fetch details for lightning wallet.
cln_address=`cat $CLN_WALLET_CONF`
if [ -z "$cln_address" ]; then echo "Failed to read $CLN_WALLET_CONF"; fi

## Configure faucet
if [ -n "$USE_FAUCET" ] && [ -z "$FAUCET_CONF" ]; then
  
  ## Search for faucet configuration file.
  printf "Searching for faucet configuration from $USE_FAUCET ... "
  FAUCET_CONF="$(find $SHARE_PATH -name $USE_FAUCET*)/$RPC_FILE"
  if [ ! -e "$FAUCET_CONF" ]; then 
    printf %b\\n "failed to locate $RPC_FILE for $peer." && exit 0
  else printf %b\\n "done."; fi
  
  ## Get connection details for peer.
  onion_host=`cat $FAUCET_CONF | kgrep rpconion`
  rpc_port=`cat $FAUCET_CONF | kgrep rpcport`
  if [ -n "$onion_host" ] && [ -z "$(onionsock -c $rpc_port)" ]; then
    onionsock -p $rpc_port $onion_host
  fi
  
  ## Checking connection to faucet.
  FAUCET_WALLET=`bitcoin-cli -conf="$FAUCET_CONF" listwallets | tr -d "\" " | tail -n +2 | head -n 1`
  printf %b\\n "Faucet configured to spend from \"$FAUCET_WALLET\" wallet."
fi

## Check if bitcoin wallet has sufficient balance.
echo "Checking bitcoin wallet balance ... "
if ! greater_than $(get_btc_balance) $MIN_FUNDS; then
  if [ -n "$SEED_NODE" ]; then 
    bitcoin-cli generatetoaddress 1 $1
  elif [ -n "$USE_FAUCET" ] && [ -z "$FAUCET_CONF" ]; then
    if ! greater_than $(faucet_cli getbalance) $MIN_FUNDS; then 
      echo "Faucet is broke!" # && mine_blocks 101 $address
    else
      printf %b\\n "Requesting funds from faucet to address $btc_address ... "
      faucet_cli sendtoaddress $1 $2
      get_funds $btc_address 5 > /dev/null 2>&1
      printf "Waiting (12s) for funds to clear ... "
      sleep 12 && printf %b\\n "done."
    fi
  else
    echo "There is no source of funds!"
  fi
fi

## Check if lightning wallet has sufficient balance.
echo "Checking lightning wallet balance ... "
if greater_than $(get_btc_balance) $MIN_FUNDS; then
  if ! greater_than $(get_cln_balance) $MIN_FUNDS; then
    printf %b\\n "Requesting funds from bitcoin wallet to address $btc_address ... "
    bitcoin-cli sendtoaddress $cln_address 1
    printf "Waiting (60s) for funds to clear ... "
    sleep 30 && printf %b\\n "done."
  fi
fi

## Print current balance of wallets.
printf %b\\n "Bitcoin: $(get_btc_balance) BTC."
printf %b\\n "Lightning: $(get_cln_balance) BTC."
