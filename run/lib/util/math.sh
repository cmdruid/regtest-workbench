## util/math.sh
## Methods for performing math operations.

greater_than() {
  [ -n "$1" ] && [ -n "$2" ] && \
  [ -n "$(echo "$1 $2" | awk '{ print ($1>=$2) }' | grep 1)" ]
}