#!/usr/bin/env bash
## Startup script for init.

set -E

###############################################################################
# Environment
###############################################################################

###############################################################################
# Script
###############################################################################

templ banner "Init Configuration"

if [ -d "$SHARE_PATH/$HOSTNAME" ]; then
  printf "Removing existing share configurations"
  rm -r $SHARE_PATH/$HOSTNAME && mkdir -p "$SHARE_PATH/$HOSTNAME"
  templ ok
fi

if [ -n "$TOR_NODE" ]; then
  sh -c $LIB_PATH/start/onion-start.sh
fi