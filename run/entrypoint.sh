#!/bin/sh
## Entrypoint script for image.

set -E

###############################################################################
# Environment
###############################################################################

WORK_PATH="$(dirname $(realpath $0))"
SHARE_PATH="/share"

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
  SHARE_PATH=$SHARE_PATH WORK_PATH=$WORK_PATH sh $script
done

echo "Node initialized!"

## Display logs.
#sh $WORK_PATH/utils/tail-logs.sh