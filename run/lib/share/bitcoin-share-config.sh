#!/usr/bin/env sh
## Write out Bitcoin peering and RPC configuration.

###############################################################################
# Environment
###############################################################################

ONION_FILE="/data/tor/services/btc/hostname"
CRED_FILE="/data/bitcoin/credentials.conf"
PEER_FILE="$SHAREPATH/$HOSTNAME/bitcoin-peer.conf"

RPC_PORT=18443
PEER_PORT=18444
ONION_PORT=18445

###############################################################################
# Script
###############################################################################

printf %b\\n "HOST_NAME=$HOSTNAME\nPEER_PORT=$PEER_PORT" > $PEER_FILE

if [ -n "$(pgrep tor)" ] && [ -e "$ONION_FILE" ]; then
  printf %b\\n "ONION_NAME=$(cat $ONION_FILE)\nONION_PORT=$ONION_PORT" >> $PEER_FILE
fi

if [ ! -e "$CRED_FILE" ] || [ -z "$(cat $CRED_FILE)" ]; then
  echo "$CRED_FILE is missing!" && exit 1
else
  rpcuser=`cat $CRED_FILE | kgrep rpcuser`
  rpcpass=`cat $CRED_FILE | kgrep rpcpassword`
  printf %b\\n "RPC_USER=$rpcuser\nRPC_PASS=$rpcpass\nRPC_PORT=$RPC_PORT" >> $PEER_FILE
fi