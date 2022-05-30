## util/timers.sh
## Methods involving timers and delays.

timeout_child() {
  ## Configure a timeout for a child process.
  [ -n "$1" ] && timeout="$1" || timeout=10
  [ -n "$2" ] && message="$2" || message="timed out after ${timeout}s"
  trap -- "" TERM
  child=$!
  ( sleep $timeout; if ps | grep $child > /dev/null; then kill $child && printf "$message"; fi ) &
  wait $child 2>/dev/null; return $?
}