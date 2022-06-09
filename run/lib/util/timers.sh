## util/timers.sh
## Methods involving timers and delays.

timeout_child() {
  ## Configure a timeout for a child process.  
  trap -- "" TERM
  child="$!"
  [ -n "$1" ] && timeout="$1" || timeout=10
  [ -n "$2" ] && message="$2" || message=""
  ( sleep $timeout; [ -n "$(ps | grep $child)" ] && kill -9 "$child" && printf "$message" ) &
  wait "$child" > /dev/null 2>&1; return $?
}