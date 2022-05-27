## util/timers.sh
## Methods involving timers and delays.

timeout_child() {
  ## Configure a timeout for a child process.
  [ -n "$1" ] && timeout="$1" || timeout=10
  trap -- "" TERM
  child=$!
  message="$2"
  ( sleep $timeout; if ps | grep $child > /dev/null; then kill $child && printf "$message"; fi ) &
  wait $child 2>/dev/null; return $?
}