## util/peers.sh
## Methods for managing peering in Bitcoin / Lightning.

get_peer_count() {
  bitcoin-cli getconnectioncount
}

is_peer_configured() {
  [ -n "$1" ] && [ -n "$(bitcoin-cli getaddednodeinfo | jgrep addednode | grep $1)" ]
}

is_peer_connected() {
  [ "$(get_peer_count)" -ne 0 ]
}

get_peer_config() {
  [ -n "$1" ] && [ -n "$2" ] && find "$SHAREPATH/$1"* -name $2 2>&1
}

