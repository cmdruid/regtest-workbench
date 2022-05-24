#!/bin/bash
## Entrypoint script for image.

set -E

###############################################################################
# Environment
###############################################################################

WORK_PATH="$(dirname $(realpath $0))"
LIB_PATH="$WORK_PATH/lib"
SHARE_PATH="/share"
IND=`fgc 215 "|-"`

###############################################################################
# Methods
###############################################################################

greeting() {
  printf "
Type '$(fgc 220 exit)' to quit the terminal. This node will continue to run in the background.
You can re-enter this terminal with the command '$(fgc 220 "docker exec -it $HOSTNAME bash")'.
  \n"
}

cleanup() {
  echo "Received shutdown signal!"
  [ $? -ne 0 ] && echo "Exiting with status $?: $0 FAILED at line ${LINENO}"
  printf "Removing shared data ..."
  rm -r "$SHARE_PATH/$HOSTNAME"
  printf %b\\n "done." && exit 0
}

finish() {
  if [ "$?" -ne 0 ]; then templ fail && exit 1; fi
}

###############################################################################
# Script
###############################################################################

trap finish EXIT

## Make sure share path exists.
share_host="$SHARE_PATH/$HOSTNAME"
if [ ! -d "$share_host" ]; then
  printf "Creating directory $share_host ... "
  mkdir -p $share_host && printf %b\\n "done."
fi

## Execute startup scripts.
for script in `find $WORK_PATH/startup -name *.sh | sort`; do
  WORK_PATH=$WORK_PATH LIB_PATH=$LIB_PATH SHARE_PATH=$SHARE_PATH IND=$IND \
  sh -c $script
done

if [ $? -ne 0 ]; then 
  templ banner "Node startup failed!" && exit 0
else

  templ banner "$HOSTNAME is initialized!"
  ip_addr=`ip -f inet addr show eth0 | grep -Po 'inet \K[\d.]+'`
  user="$(cat /data/lightning/sparko.login | kgrep USERNAME)"
  pass="$(cat /data/lightning/sparko.login | kgrep PASSWORD)"

  printf "$(tput bold)Node ID:$(tput sgr0)      $(lightning-cli getinfo | jgrep id)\n\n"
  printf "$(tput bold)Wallet Link:$(tput sgr0)  $(fgc 033 "http://$ip_addr:9737")\n"
  printf "$(tput bold)Wallet Login:$(tput sgr0) $user // $pass\n"

fi

greeting

## Setup session for normal mode.
if [ -z "$DEVMODE" ] || [ "$DEVMODE" -eq 0 ]; then
  trap cleanup SIGTERM
  greeting && /bin/bash
fi