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

## Purge existing shared files.
if [ -d "$SHAREPATH/$HOSTNAME" ]; then
  printf "Purging existing share configurations"
  rm -r $SHAREPATH/$HOSTNAME && templ ok
fi

mkdir -p "$SHAREPATH/$HOSTNAME" 

## If tor enabled, call tor startup script.
if [ -n "$TOR_NODE" ]; then sh -c $LIBPATH/start/onion-start.sh; fi