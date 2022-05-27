## util/wallet.sh
## Methods for managing the Bitcoin Core wallet.

is_wallet_loaded() {
  [ -n "$1" ] && name="$1" || ( echo "Failed to provide wallet name!" && exit 1 )
  [ -n "$(bitcoin-cli listwallets | grep $name)" ]
}

is_wallet_created() {
  [ -n "$1" ] && name="$1" || ( echo "Failed to provide wallet name!" && exit 1 )
  [ -n "$(bitcoin-cli listwalletdir | jgrep name | grep $name)" ]
}

is_address_created() {
  [ -n "$1" ] && label="$1"  || ( echo "Failed to provide address label!" && exit 1 )
  [ -n "$2" ] && wallet="$2" || ( echo "Failed to provide wallet name!" && exit 1 )
  bitcoin-cli -rpcwallet=$wallet listlabels | grep $label > /dev/null 2>&1
}

create_address() {
  [ -n "$1" ] && label="$1"  || ( echo "Failed to provide address label!" && exit 1 )
  [ -n "$2" ] && wallet="$2" || ( echo "Failed to provide wallet name!" && exit 1 )
  bitcoin-cli -rpcwallet=$wallet getnewaddress $label > /dev/null 2>&1
}

get_address() {
  [ -n "$1" ] && label="$1" || ( echo "Failed to provide address label!" && exit 1 )
  bitcoin-cli -rpcwallet=$2 getaddressesbylabel $label \
    | grep -E 'bc[[:alnum:]]{42}' \
    | tr '":{' ' ' \
    | awk '{$1=$1};1'
}