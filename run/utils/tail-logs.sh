#!/bin/sh
## Tail multiple logs.

set -e

###############################################################################
# Environment
###############################################################################

LOGS="
  /var/log/tor/notice.log,
  /var/log/bitcoin/debug.log,
  /var/log/lightningd.log,
  /var/log/cl-rest.log
"

###############################################################################
# Methods
###############################################################################

log_string() {
  echo "$(
    for log in $(echo $LOGS | tr ',' '\n'); do
      if [ -e "$log" ]; then echo $log; fi
    done | tr '\n' ' '
  )"
}

###############################################################################
# Script
###############################################################################

## Start tailing log files.
tail -f `log_string`