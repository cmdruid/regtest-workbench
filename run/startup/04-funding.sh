#!/bin/sh
## Startup script for funding the node.

set -E

###############################################################################
# Environment
###############################################################################

BTC_DATA_PATH="/data/bitcoin"
CLN_DATA_PATH="/data/lightning"

BTC_FUND_FILE="$BTC_DATA_PATH/wallet.conf"
CLN_FUND_FILE="$CLN_DATA_PATH/fund.address"

DEFAULT_RPC_SOCK=18446
DEFAULT_MIN_FUNDS=1

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
  bitcoin-cli $FAUCET_CONF -rpcwallet="$FAUCET_WALLET" $@
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

printf "
=============================================================================
  Funding Configuration
=============================================================================
\n"

## Abort early if all daemons are not running.
if [ -z "$(pgrep bitcoind)" ] && [ -z "$(pgrep lightningd)" ]; then 
  echo "Some daemons refused to load. Aborting!" && exit 1
fi

## Set default values.
if [ -z "$RPC_SOCK" ]; then RPC_SOCK=$DEFAULT_RPC_SOCK; fi
if [ -z "$MIN_FUNDS" ]; then MIN_FUNDS=$DEFAULT_MIN_FUNDS; fi

## Fetch details for bitcoin wallet.
btc_address=`cat "$BTC_FUND_FILE" | kgrep ADDRESS`
if [ -z "$btc_address" ]; then echo "Failed to read btc wallet!" && exit 1; fi

## Fetch details for lightning wallet.
cln_address=`cat $CLN_FUND_FILE`
if [ -z "$cln_address" ]; then echo "Failed to read cln wallet!" && exit 1; fi

## Configure faucet
if [ -n "$USE_FAUCET" ]; then

  ## Search for peer file in peers path.
  printf "Searching for connection settings from $USE_FAUCET ... "
  config=`find "$SHARE_PATH/$USE_FAUCET"* -name bitcoin-peer.conf`

  ## Exit out if peer file is not found.
  if [ ! -e "$config" ]; then printf %b\\n "failed!" && continue; fi
  printf %b\\n " done."

  ## Parse current peering info.
  onion_host=`cat $config | kgrep ONION_NAME`
  rpc_user=`cat $config | kgrep RPC_USER`
  rpc_pass=`cat $config | kgrep RPC_PASS`

  if [ -n "$(pgrep tor)" ] && [ -n "$onion_host" ]; then
    peer_host="127.0.0.1"
    rpc_port="$RPC_SOCK"
    remote_port=`cat $config | kgrep RPC_PORT`
    if [ -z "$(onionsock -c $RPC_SOCK)" ]; then 
      onionsock -p $RPC_SOCK "$onion_host:$remote_port"
    fi
  else
    peer_host="$(cat $config | kgrep HOST_NAME)"
    rpc_port=`cat $config | kgrep RPC_PORT`
  fi

  ## Checking connection to faucet.
  FAUCET_CONF="-rpcconnect=$peer_host -rpcport=$rpc_port -rpcuser=$rpc_user -rpcpassword=$rpc_pass"
  FAUCET_WALLET=`bitcoin-cli $FAUCET_CONF listwallets | tr -d "\" " | tail -n +2 | head -n 1`

  if [ -z "$FAUCET_WALLET" ]; then 
    printf %b\\n "Faucet configuration failed!"
  else
    printf %b\\n "Faucet configured to spend from \"$FAUCET_WALLET\" wallet."
  fi
fi

## Check if bitcoin wallet has sufficient balance.
printf "Checking bitcoin wallet balance ... "
btc_balance=`get_btc_balance` && printf %b\\n "$btc_balance BTC."

## If bitcoin balance is low, get funds from faucet.
if ! greater_than $btc_balance $MIN_FUNDS; then
  printf "Bitcoin funds are low! Searching for funding ... "
  if [ -n "$SEED_NODE" ]; then
    printf "mining blocks for funds ... "
    bitcoin-cli generatetoaddress 5 $btc_address > /dev/null 2>&1 && printf %b\\n "done."
  elif [ -n "$USE_FAUCET" ] && [ -n "$FAUCET_WALLET" ]; then
    printf "checking faucet ... "
    if ! greater_than $(faucet_cli getbalance) $MIN_FUNDS; then 
      printf %b\\n "faucet is broke!"
    else
      printf "sending funds to address $btc_address ... "
      faucet_cli sendtoaddress $btc_address 10 > /dev/null 2>&1
      printf "waiting for funds to clear ."
      while ! greater_than $(get_btc_balance) $MIN_FUNDS; do sleep 1 && printf "."; done
      printf %b\\n " done."
      printf %b\\n "New Bitcoin balance: $(get_btc_balance) BTC."
    fi
  else
    echo "no source for funds!"
  fi
fi

## Check if lightning wallet has sufficient balance.
printf "Checking lightning wallet balance ... "
cln_balance=`get_cln_balance` && printf %b\\n "$cln_balance BTC."

## If lightning balance is low, transfer funds from main wallet.
if ! greater_than $cln_balance $MIN_FUNDS; then
  printf "Lightning funds are low! Searching for funding ... "
  if ! greater_than $(get_btc_balance) $MIN_FUNDS; then
    printf %b\\n "your bitcoin wallet is broke!"
  else
    printf "sending funds to address $cln_address ... "
    rounded_funds=`get_btc_balance | awk -F '.' '{ print $1}'`
    bitcoin-cli sendtoaddress $cln_address $((rounded_funds / 4)) > /dev/null 2>&1
    printf "waiting for funds to clear ."
    while ! greater_than $(get_cln_balance) $MIN_FUNDS; do sleep 1 && printf "."; done
    printf %b\\n " done."
    printf %b\\n "New Lightning balance: $(get_cln_balance) BTC."
  fi
fi

## Open a lightning channels with peers.
sat_amt="5000000"
for peer in `lcli getconnectedpeers`; do
  if [ "$(lcli peerchannelcount $peer)" -eq 0 ]; then
    printf "Opening channel with $peer for $sat_amt sats ... "
    lightning-cli fundchannel id=$peer amount=$sat_amt > /dev/null 2>&1
    printf %b\\n "done."
  fi
done