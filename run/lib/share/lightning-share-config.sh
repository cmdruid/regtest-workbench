#!/usr/bin/env sh
## Write out Bitcoin peering and RPC configuration.

###############################################################################
# Environment
###############################################################################

ONION_FILE="/data/tor/services/cln/hostname"
PEER_FILE="$SHAREPATH/$HOSTNAME/lightning-peer.conf"

PEER_PORT=9735
RPC_PORT=9737
REST_PORT=3001

###############################################################################
# Script
###############################################################################

node_info=`lightning-cli getinfo`

if [ -z "$node_info" ]; then 
  printf %b\\n "failed to connect to lightning RPC!" && exit 1
fi

printf %b\\n "HOST_NAME=$HOSTNAME" > $PEER_FILE

if [ -n "$(pgrep tor)" ] && [ -e "$ONION_FILE" ]; then
  printf %b\\n "ONION_NAME=$(cat $ONION_FILE)" >> $PEER_FILE
fi

printf %b\\n "PEER_PORT=$PEER_PORT\nRPC_PORT=$RPC_PORT\nREST_PORT=$REST_PORT" >> $PEER_FILE
printf %b\\n "NODE_ID=$(printf "$node_info" | jgrep id)" >> $PEER_FILE
printf %b\\n "NODE_ALIAS=$(printf "$node_info" | jgrep alias)" >> $PEER_FILE
printf %b\\n "NODE_COLOR=$(printf "$node_info" | jgrep color)" >> $PEER_FILE
