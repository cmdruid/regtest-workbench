#!/usr/bin/env sh
## Startup script for docker container.

###############################################################################
# Environment
###############################################################################

DEFAULT_DOMAIN="regtest"  
     
DENVPATH=".env"         ## Path to your local .env file.
WORKPATH="$(pwd)"       ## Absolute path to use for this directory.
LINE_OUT="/dev/null"    ## Default output for noisy commands.
ESC_KEYS="ctrl-z"       ## Escape sequence for detaching from terminals.
HEADMODE="-i"           ## Container connects to terminal by default.

DATAPATH="data"         ## Default path for a node's interal storage.
SHAREPATH="share"       ## Default path to publish connection info.

###############################################################################
# Usage
###############################################################################

usage() {
  printf "
Usage: $(basename $0) [ OPTIONS ] TAG

Launch a docker container for bitcoin / lightning development.

Example: $(basename $0) --miner start master
         $(basename $0) --faucet master start alice
         $(basename $0) --faucet master --channels=alice start bob

Arguments:
  TAG             Tag name used to identify the container.

Build Options  |  Parameters  |  Description
  -h, --help                     Display this help text and exit.
  -b, --build                    Build a new dockerfile image, using existing cache.
  -r, --rebuild                  Delete the existing cache, and build a new image from source.
  -d, --domain    STRING         Set the top-level domain name for the container (Default is $DEFAULT_NAME).
  -i, --devmode                  Start container in devmode (mounts ./run, does not start entrypoint).
  -H, --headless                 Start container in headless mode (does not connect to terminal at start).
  -T, --passthru  STRING         Pass through an argument string to the docker run script.
  -w, --wipe                     Delete the existing data volume, and create a new volume.
  -m, --miner                    Configure this as a mining node (generates blocks and clears mempool).
  -m, --miner=    POLL,INT,FUZZ  Provide an optional configuration to the mining node.
  -t, --tor                      Enable the use of Tor and onion services for this node.
  -l, --local                    When combined with --tor, forces local peering but allows hidden services.
  -p, --peers     TAG1,TAG2      List the peer nodes to connect to (for Bitcoin / Lightning nodes).
  -c, --channels  TAG1,TAG2      List the peer nodes to open channels with (for Lightning nodes).
  -f, --faucet    TAG            Specify a node to use as a faucet (usually a mining node).
  -M, --mount     INT:EXT        Declare a path to mount within the container. Can be declared multiple times.
  -P, --ports     PORT1,PORT2    List a comma-separated string of ports to open within the container.
  -v, --verbose                  Outputs more information into the terminal (useful for debugging).

Other Options:
  compile                        Checks build/out and compiles any missing binary files.
  login           TAG            Login to an existing node that is currently running.

Examples:
  --mine=poll,int,fuzz      Configure your mining node to poll every x seconds for transactions,
  (e.x --mine=2,60,20)      or mine blocks continuously at an interval (or both!). If you are running
                            multiple mining nodes, set the fuzz value to add random variation to each
                            block, or you may get chain splits! All params are denominated in seconds,
                            setting to zero disables that feature.
  
  --mount app:/root/app     Declares a path to be mounted within the container. Paths can be relative 
                            or absolute.

  --ports 9375,80:8080      Declare a list of ports to be forwarded from within the container. You can
                            also specify a different internal:external destination for each port.

For more information, or if you want to report any bugs / issues, 
please visit the github page: https://github.com:cmdruid/regtest-workbench
\n"
}

###############################################################################
# Methods
###############################################################################

chk_arg() {
  ( [ -z "$1" ] || [ -n "$(echo $1 | grep -E '^-')" ] ) \
  && echo "Bad value! Received an argument instead: $1" && exit 1 \
  || return 0
}

add_arg() {
  ## Construct a string of arguments.
  chk_arg $1 && ARGS_STR="$ARGS_STR -e $1"
}

add_mount() {
  ## If mount points are specified, build a mount string.
  if chk_arg $1; then
    src=`printf $1 | awk -F ':' '{ print $1 }'`
    dest=`printf $1 | awk -F ':' '{ print $2 }'`
    if [ -z "$(echo $1 | grep -E '^/')" ]; then prefix="$WORKPATH/"; fi
    MOUNTS="$MOUNTS --mount type=bind,source=$prefix$src,target=$dest"
  fi
}

add_ports() {
  ## If ports are specified, build a port string.
  if chk_arg $1; then for port in `echo $1 | tr ',' ' '`; do
    src=`printf $1 | awk -F ':' '{ print $1 }'`
    dest=`printf $1 | awk -F ':' '{ print $2 }'`
    if [ -z "$dest" ]; then dest="$src"; fi
    PORTS="$PORTS -p $src:$dest"
  done; fi
}

read_env() {
  ## Read a key=value store and convert into a string.
  [ -n "$1" ] && \
  while read line || [ -n "$line" ]; do
    if ! printf %s "$line" | egrep -q '^ *#'; then printf %s "-e ${line} "; fi
  done < "$1"
}

image_exists() {
  [ -n "$1" ] && docker image ls | grep $1 > $LINE_OUT 2>&1
}

container_exists() {
  docker container ls -a | grep $SRV_NAME > $LINE_OUT 2>&1
}

volume_exists() {
  docker volume ls | grep $DAT_NAME > $LINE_OUT 2>&1
}

network_exists() {
  docker network ls | grep $NET_NAME > $LINE_OUT 2>&1
}

check_binaries() {
  if [ ! -d "build/out" ]; then mkdir -p build/out; fi
  for file in build/dockerfiles/*; do
    name="$(basename -s .dockerfile $file)"
    if [ -z "$(ls build/out | grep $name)" ]; then 
      printf "Binary for $name is missing! Building from source ..."
      BUILDPATH=$WORKPATH/build build/build.sh $file 
    fi
  done
  [ -n "$EXT" ] && echo "All binary files are compiled and ready!"
}

build_image() {
  check_binaries
  printf "Building image for $IMG_NAME from dockerfile ... "
  if [ -n "$VERBOSE" ]; then printf "\n"; fi
  DOCKER_BUILDKIT=1 docker build --tag $IMG_NAME . > $LINE_OUT 2>&1
  if ! image_exists $IMG_NAME; then printf "failed!\n" && exit 1; fi
  printf "done.\n"
}

remove_image() {
  printf "Removing existing image ... "
  if [ -n "$VERBOSE" ]; then printf "\n"; fi
  docker image rm $IMG_NAME > $LINE_OUT 2>&1
  if image_exists $IMG_NAME; then printf "failed!\n" && exit 1; fi
  printf "done.\n"
}

create_network() {
  printf "Creating network $NET_NAME ... "
  if [ -n "$VERBOSE" ]; then printf "\n"; fi
  docker network create $NET_NAME > $LINE_OUT 2>&1;
  if ! network_exists; then printf "failed!\n" && exit 1; fi
  printf "done.\n"
}

get_container_id() {
  [ -z "$1" ] && echo "You provided an empty search tag!" && exit 1
  docker container ls | grep $1 | awk '{ print $1 }' | head -n 2 | tail -n 1
}

login_container() {
  cid=`get_container_id $1`
  [ -z "$cid" ] && echo "That node does not exist!" && exit 3
  docker exec -it --detach-keys $ESC_KEYS $cid terminal
}

stop_container() {
  if container_exists; then
    printf "Purging existing container ... "
    if [ -n "$VERBOSE" ]; then printf "\n"; fi
    docker container stop $SRV_NAME > $LINE_OUT 2>&1
    docker container rm $SRV_NAME > $LINE_OUT 2>&1
    if container_exists; then printf "failed!\n" && exit 1; fi
    printf "done.\n"
  fi
}

wipe_data() {
  printf "Purging existing data volume ... "
  if [ -n "$VERBOSE" ]; then printf "\n"; fi
  docker volume rm $DAT_NAME > $LINE_OUT 2>&1
  if volume_exists; then printf "failed!\n" && exit 1; fi
  printf "done.\n"
}

cleanup() {
  ## Exit codes are complicated.
  status="$?"
  [ -n "$EXT" ] || [ -n "$HEADLESS" ] && exit 0
  [ -z $DEVMODE ] && ([ $status -eq 1 ] || ([ -n "$LOGIN" ] && [ $status -lt 2 ])) \
    && echo "You are now logged out. Node running in the background." && exit 0
  stop_container && echo "Clean exit with status: $status" && exit 0
}

###############################################################################
# Main
###############################################################################

main() {
  [ -n "$VERBOSE" ] && echo "Configuration string: $MOUNTS $PORTS $ENV_STR $ARGS_STR\n"

  ## Start container script.
  docker run -t \
    --name $SRV_NAME \
    --hostname $SRV_NAME \
    --network $NET_NAME \
    --mount type=bind,source=$WORKPATH/$SHAREPATH,target=/$SHAREPATH \
    --mount type=volume,source=$DAT_NAME,target=/$DATAPATH \
    -e DATAPATH="/$DATAPATH" -e SHAREPATH="/$SHAREPATH" -e ESC_KEYS="$ESC_KEYS" \
  $HEADMODE $RUN_FLAGS $MOUNTS $PORTS $ENV_STR $ARGS_STR $PASSTHRU $IMG_NAME:latest
}

###############################################################################
# Script
###############################################################################

set -E && trap cleanup EXIT

## Parse arguments.
for arg in "$@"; do
  case $arg in
    login)             LOGIN=1; login_container $2;      exit   ;;
    compile)           EXT=1; check_binaries;            exit   ;;
    start)             TAG=$2                            shift 2;;
    -h|--help)         usage;                            exit   ;;
    -b|--build)        BUILD=1;                          shift  ;;
    -r|--rebuild)      REBUILD=1;                        shift  ;;
    -w|--wipe)         WIPE=1;                           shift  ;;
    -i|--devmode)      DEVMODE=1;                        shift  ;;
    -v|--verbose)      VERBOSE=1;                        shift  ;;
    -H|--headless)     HEADLESS=1;                       shift  ;;
    -T|--passthru)     PASSTHRU=$2;                      shift 2;;                      
    -D|--domain)       DOMAIN=$2;                        shift 2;;
    -M|--mount)        add_mount $2;                     shift 2;;
    -P|--ports)        add_ports $2;                     shift 2;;
    -p|--peers)        add_arg "PEER_LIST=$2";           shift 2;;
    -c|--channels)     add_arg "CHAN_LIST=$2";           shift 2;;
    -f|--faucet)       add_arg "USE_FAUCET=$2";          shift 2;;
    -m|--miner)        add_arg "MINE_NODE=DEFAULT";      shift  ;;
    -m=*|--miner=*)    add_arg "MINE_NODE=${arg#*=}";    shift  ;;
    -t|--tor)          add_arg "TOR_NODE=1";             shift  ;;
    -l|--local)        add_arg "LOCAL_ONLY=1";           shift  ;;
  esac
done

## If no name argument provied, display help and exit.
[ -z "$TAG" ] && [ -z "$1" ] && usage && exit
[ -z "$TAG" ] && [ -n "$1" ] && TAG=$1

## Set default variables and flags.
[ -z "$DOMAIN" ]   && DOMAIN="$DEFAULT_DOMAIN"
[ -n "$VERBOSE" ]  && LINE_OUT="/dev/tty"
[ -n "$HEADLESS" ] && HEADMODE=""
[ -e "$ENV_PATH" ] && ENV_STR=`read_env $ENV_PATH`

## Define naming scheme.
IMG_NAME="$DOMAIN-img"
NET_NAME="$DOMAIN-net"
SRV_NAME="$TAG.$DOMAIN.node"
DAT_NAME="$TAG.$DOMAIN.data"

## Make sure sharepath is created.
echo $WORKPATH > /dev/null ## Silly work-around for a silly bug.
if [ ! -d "$WORKPATH/$SHAREPATH" ]; then mkdir -p "$WORKPATH/$SHAREPATH"; fi

## If there's an existing container, remove it.
stop_container

## If rebuild is declared, remove existing image.
if image_exists $IMG_NAME && [ -n "$REBUILD" ]; then remove_image; fi

## If no existing image is present, build it.
if ! image_exists $IMG_NAME || [ -n "$BUILD" ]; then build_image; fi

## If no existing network exists, create it.
if ! network_exists; then create_network; fi

## Purge data volume if flagged for removal.
if volume_exists && [ -n "$WIPE" ]; then wipe_data; fi

## Set flags and run mode of container.
if [ -n "$DEVMODE" ]; then
  DEV_MOUNT="type=bind,source=$WORKPATH/run,target=/root/run"
  RUN_MODE="development"
  RUN_FLAGS="--mount $DEV_MOUNT -e DEVMODE=1"
  [ -n "$HEADLESS" ] \
    && RUN_FLAGS="$RUN_FLAGS --detach" \
    || RUN_FLAGS="$RUN_FLAGS --rm --entrypoint bash"
else
  RUN_MODE="safe"
  RUN_FLAGS="--init --detach --restart on-failure:2"
fi

## Call main container script based on run mode.
echo "Starting container for $SRV_NAME in $RUN_MODE mode ..."
if [ -n "$HEADLESS" ]; then
  main
elif [ -n "$DEVMODE" ]; then
  echo "Enter the command 'node-start' to begin the node startup script:" && main
else
  cid=`main` && docker attach --detach-keys $ESC_KEYS $cid
fi
