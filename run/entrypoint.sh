#!/bin/sh
## Entrypoint script for image.

set -E

###############################################################################
# Environment
###############################################################################

WORK_PATH="$(dirname $(realpath $0))"
SHARE_PATH="/share"

###############################################################################
# Methods
###############################################################################

cleanup() {
  echo "Received shutdown signal!"
  [ $? -ne 0 ] && echo "Exiting with status $?: $0 FAILED at line ${LINENO}"
  printf "Removing shared data ..."
  rm -r "$SHARE_PATH/$HOSTNAME"
  printf %b\\n "done." && exit 0
}

###############################################################################
# Script
###############################################################################

## Make sure share path exists.
share_host="$SHARE_PATH/$HOSTNAME"
if [ ! -d "$share_host" ]; then
  printf "Creating directory $share_host ... "
  mkdir -p $share_host && printf %b\\n "done."
fi

## Execute startup scripts.
for script in `find $WORK_PATH/startup -name *.sh | sort`; do
  SHARE_PATH=$SHARE_PATH WORK_PATH=$WORK_PATH sh -c $script
done

if [ $? -ne 0 ]; then 
  BANNER_MSG="Node startup failed!"
else 
  ip_addr=`ip -f inet addr show eth0 | grep -Po 'inet \K[\d.]+'`
  BANNER_MSG="Node Initialized! Wallet Link: http://$ip_addr:9737"
fi

printf %b\\n "
=============================================================================
  $BANNER_MSG
=============================================================================
"

## Setup container for detatched mode.
if [ -z "$DEVMODE" ]; then
  trap 'true' SIGTERM
  .$WORK_PATH/lib/tail-logs.sh &
  wait $!
  cleanup
fi