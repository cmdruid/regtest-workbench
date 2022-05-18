#!/bin/sh
## Startup script for init.

set -E

###############################################################################
# Environment
###############################################################################

###############################################################################
# Script
###############################################################################

printf "
=============================================================================
  Init Configuration
=============================================================================
\n"

if [ -d "$SHARE_PATH/$HOSTNAME" ]; then
  printf "Removing existing share configurations ... "
  rm -r $SHARE_PATH/$HOSTNAME && mkdir -p "$SHARE_PATH/$HOSTNAME"
  printf %b\\n "done."
fi

if [ -n "$TOR_ENABLED" ]; then
  sh -c $WORK_PATH/lib/onion-setup.sh && wait
fi