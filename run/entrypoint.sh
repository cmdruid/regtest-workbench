#!/usr/bin/env bash
## Entrypoint script for image.

set -E

###############################################################################
# Environment
###############################################################################

IND=`fgc 215 "|-"`

###############################################################################
# Methods
###############################################################################

greeting() {
  printf "Press '$(fgc 220 $ESC_KEYS)' to detatch from the terminal. Your node will continue to run in the background.
You can re-enter this terminal with the command '$(fgc 220 "docker exec -it $HOSTNAME bash")'.\n\n"
}

cleanup() {
  status="$?" && [ $status -ne 0 ] || [ -n "$DEVMODE" ] \
    && printf "Exiting with status $?. Cleaning up ..." \
    && rm -r "$SHAREPATH/$HOSTNAME" && printf "done.\n" && exit 0
}

###############################################################################
# Script
###############################################################################

trap cleanup SIGTERM SIGKILL EXIT

## Add a little delay for docker to attach the tty properly.
if [ -z "$DEVMODE" ]; then sleep 1; fi

## Execute startup scripts.
for script in `find $RUNPATH/startup -name *.sh | sort`; do
  IND=$IND sh -c $script
done

## Print a fancy banner depending on startup success / failure.
if [ $? -ne 0 ]; then 
  templ banner "Node startup failed!" && exit 1
else

  templ banner "$HOSTNAME is initialized!"
  ip_addr=`ip -f inet addr show eth0 | grep -Po 'inet \K[\d.]+'`
  spark_key=`cat /data/lightning/sparko.keys | kgrep STREAM_KEY`
  spark_user=`cat /data/lightning/sparko.login | kgrep USERNAME`
  spark_pass=`cat /data/lightning/sparko.login | kgrep PASSWORD`
  stream_uri="stream?access-key=$(printf $spark_key | awk -F ':' '{ print $1 }')"

  printf "$(tput bold)Node ID:$(tput sgr0)      $(lightning-cli getinfo | jgrep id)\n"
  printf "$(tput bold)Stream Link:$(tput sgr0)  $(fgc 033 "http://$ip_addr:9737/$stream_uri")\n\n"
  printf "$(tput bold)Wallet Link:$(tput sgr0)  $(fgc 033 "http://$ip_addr:9737")\n"
  printf "$(tput bold)Wallet Login:$(tput sgr0) $spark_user // $spark_pass\n"
  echo

fi

## Setup session for safe mode.
if [ -z "$DEVMODE" ]; then greeting && /bin/bash; fi