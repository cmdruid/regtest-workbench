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

is_node_connected() {
  [ -n "$1" ] && [ -n "$(lightning-cli listpeers | jgrep id | grep $1)" ]
}

is_channel_confirmed() {
  [ -n "$1" ] && lcli peerchannelcount "$1"
}

is_channel_funded() {
  [ -n "$1" ] && [ "$(lcli peerchannelbalance "$1")" != "0" ]
}

###############################################################################
# Script
###############################################################################

if [ "$?" -ne 0 ]; then exit 1; fi

templ banner "Funding Configuration"

## Abort early if all daemons are not running.
if [ -z "$(pgrep bitcoind)" ] && [ -z "$(pgrep lightningd)" ]; then 
  printf "Some daemons refused to load. Aborting!"
  templ fail && exit 1
fi

## Set default values.
if [ -z "$RPC_SOCK" ]; then RPC_SOCK=$DEFAULT_RPC_SOCK; fi
if [ -z "$MIN_FUNDS" ]; then MIN_FUNDS=$DEFAULT_MIN_FUNDS; fi

## Fetch details for bitcoin wallet.
btc_address=`cat "$BTC_FUND_FILE" | kgrep ADDRESS`
if [ -z "$btc_address" ]; then 
  printf "Failed to read btc wallet!"
  templ fail && exit 1
fi

## Fetch details for lightning wallet.
cln_address=`cat $CLN_FUND_FILE`
if [ -z "$cln_address" ]; then 
  printf "Failed to read cln wallet!"
  templ fail && exit 1
fi

## Configure faucet
if [ -n "$USE_FAUCET" ]; then

  ## Search for peer file in peers path.
  printf "Searching for faucet settings from $USE_FAUCET"
  config=`find "$SHARE_PATH/$USE_FAUCET"* -name bitcoin-peer.conf`

  ## Exit out if peer file is not found.
  if [ ! -e "$config" ]; then templ fail && continue; fi
  templ ok && echo

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
    printf "Faucet configuration failed!" && templ fail
  else printf "Connected to faucet \"$FAUCET_WALLET\" wallet" && templ conn; fi
  echo
fi

## Check if bitcoin wallet has sufficient balance.
printf "Checking bitcoin wallet balance"
btc_balance=`get_btc_balance`

## If bitcoin balance is low, get funds from faucet.
if ! greater_than $btc_balance $MIN_FUNDS; then
  printf ":\n| Bitcoin funds are low!\n| Searching for funding ... "
  if [ -n "$MINE_NODE" ]; then
    printf "\n| Mining blocks for funds"
    bitcoin-cli generatetoaddress 5 $btc_address > /dev/null 2>&1
    if ! greater_than $(get_btc_balance) $MIN_FUNDS; then
      printf " ...\n| No coinbase in reserve!\n| Mining 100 more blocks"
      bitcoin-cli generatetoaddress 150 $btc_address > /dev/null 2>&1
      if ! greater_than $(get_btc_balance) $MIN_FUNDS; then
        printf " ...\n| We are still broke! Something is wrong!" && templ fail
      else templ ok; fi
    else templ ok; fi
  elif [ -n "$USE_FAUCET" ] && [ -n "$FAUCET_WALLET" ]; then
    printf "\n| checking faucet ... "
    if ! greater_than $(faucet_cli getbalance) $MIN_FUNDS; then 
      printf "faucet is broke!" && templ fail
    else
      printf "\n| Funding address $btc_address"
      faucet_cli sendtoaddress $btc_address 10 > /dev/null 2>&1
      printf "\n| Waiting for funds to clear ."
      while ! greater_than $(get_btc_balance) $MIN_FUNDS; do sleep 1 && printf "."; done
      templ ok
      printf "| New Bitcoin balance:" && templ brkt "$(get_btc_balance) BTC."
    fi
  else printf "\n| No source for funds!" && templ fail; fi
  echo
else templ brkt "$btc_balance BTC."; fi

## Check if lightning wallet has sufficient balance.
printf "Checking lightning wallet balance"
cln_balance=`get_cln_balance`

## If lightning balance is low, transfer funds from main wallet.
if ! greater_than $cln_balance $MIN_FUNDS; then
  printf ":\n| Lightning funds are low! Searching for funding ... "
  if ! greater_than $(get_btc_balance) $MIN_FUNDS; then
    printf "\n| Your bitcoin wallet is broke!" && templ fail
  else
    printf "\n| Funding address: $cln_address"
    rounded_funds=`get_btc_balance | awk -F '.' '{ print $1}'`
    bitcoin-cli sendtoaddress $cln_address $((rounded_funds / 4)) > /dev/null 2>&1
    printf "\n| Waiting for funds to clear ."
    while ! greater_than $(get_cln_balance) $MIN_FUNDS; do sleep 1 && printf "."; done
    templ ok
    printf "| New Lightning balance:" && templ brkt "$(get_cln_balance) BTC."
  fi
else
  templ brkt "$cln_balance BTC."
fi

## Open a lightning channels with peers.
if [ -n "$CHAN_LIST" ]; then
  sat_amt="5000000"
  for peer in $(printf $CHAN_LIST | tr ',' ' '); do
    
    ## Search for peer file in peers path.
    printf "Checking channel with $peer:\n"
    config=`find $SHARE_PATH/$peer* -name lightning-peer.conf`

    ## Exit out if peer file is not found.
    if [ ! -e "$config" ]; then templ fail && continue; fi

    ## Parse current peering info.
    node_id=`cat $config | kgrep NODE_ID`
  
    ## If valid peer, then connect to node.
    if is_node_connected $node_id; then
      if ! is_channel_confirmed; then
        printf "| Opening channel with $peer for $sat_amt sats."
        printf "\n| Waiting for channel to confirm ."
        lightning-cli fundchannel $node_id $sat_amt > /dev/null 2>&1
        while ! is_channel_funded $node_id > /dev/null 2>&1; do sleep 1 && printf "."; done
        templ ok
      fi
      printf "| Channel balance for $peer"
      templ brkt "$(lcli peerchannelbalance $node_id)"
    else
      printf "| No connection to $peer!" && templ fail
    fi
  done
fi