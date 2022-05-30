## util/peers.sh
## Methods for managing peering in Bitcoin / Lightning.

is_peer_configured() {
  [ -n "$1" ] && [ -n "$(bitcoin-cli getaddednodeinfo | jgrep addednode | grep $1)" ]
}

is_peer_connected() {
  [ -n "$1" ] && [ "$(bitcoin-cli getaddednodeinfo $1 2>&1 | jgrep connected | head -n 1)" = "true" ]
}

get_peer_config() {
  [ -n "$1" ] && [ -n "$2" ] && find "$SHAREPATH/$1"* -name $2 2>&1
}

get_peer_count() {
  bitcoin-cli getconnectioncount
}