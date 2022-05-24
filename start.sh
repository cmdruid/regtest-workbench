#!/bin/sh
## Startup script for docker container.

###############################################################################
# Environment
###############################################################################

DEFAULT_DOMAIN="regtest"
ENV_PATH=".env"
TERM_OUT="/dev/null"
ARGS_STR=""
DOCKER_BUILDKIT=1

###############################################################################
# Usage
###############################################################################

usage() {
  printf %b\\n "
Usage: $(basename $0) [ OPTIONS ] TAG

Launch a docker container for bitcoin / lightning development.

Example: $(basename $0) --mine master
         $(basename $0) --faucet=master --peers=master --channels=master alice
         $(basename $0) --faucet=master --peers=master,alice --channels=alice bob

Arguments:
  TAG                       Tag name used to identify the container.

Options:
  -h, --help                Display this help text and exit.
  -b, --build               Build a new dockerfile image, using existing cache.
  -r, --rebuild             Delete the existing cache, and build a new image from source.
  -w, --wipe                Delete the existing data volume, and create a new volume.
  -i, --interactive         Start a new container in interactive mode (does not launch entrypoint.sh).
  -v, --verbose             Outputs more information into the terminal (useful for debugging).
  -n, --name                Set the top-level domain name for the container (Default is $DEFAULT_NAME).
  -t, --tor                 Enable the use of Tor and onion services for this node.
  -m, --mine                Specify this as a mining node (generates blocks and clears mempool).
  -p, --peers=tag1,tag2     Specify the peer nodes to connect to (for Bitcoin / Lightning nodes).
  -c, --channels=tag1,tag2  Specify the peer nodes to open channels with (for Lightning nodes).
  -f, --faucet=tag          Specify a node to use as a faucet (usually a mining node).

Details:
  --mine=poll,int,fuzz      Configure your mining node to poll every x seconds for transactions,
  (e.x --mine=2,60,20)      or mine blocks continuously at an interval (or both!). If you are running
                            multiple mining nodes, set the fuzz value to add random variation to each
                            block, or you may get chain splits! All params are denominated in seconds,
                            setting to zero disables that feature.

For more information, or if you want to report any bugs / issues, 
please visit the github page: https://github.com:cmdruid/regtest-node
"
}

###############################################################################
# Methods
###############################################################################

add_arg() {
  [ -n "$1" ] && ARGS_STR="$ARGS_STR -e $1"
}

read_env() {
  [ -n "$1" ] && \
  while read line || [ -n "$line" ]; do
    if ! printf %s "$line" | egrep -q '^ *#'; then printf %s "-e ${line} "; fi
  done < "$1"
}

image_exists() {
  docker image ls | grep $IMG_NAME > /dev/null 2>&1
}

container_exists() {
  docker container ls -a | grep $SRV_NAME > /dev/null 2>&1
}

volume_exists() {
  docker volume ls | grep $DAT_NAME > /dev/null 2>&1
}

network_exists() {
  docker network ls | grep $NET_NAME > /dev/null 2>&1
}

check_binaries() {
  if [ ! -d "build/out" ]; then mkdir -p build/out; fi
  for file in build/dockerfiles/*; do
    name="$(basename -s .dockerfile $file)"
    if [ -z "$(ls build/out | grep $name)" ]; then 
      printf "Binary for $name is missing! Building from source ..."
      build/build.sh $file 
    fi
  done
  [ -n "$COMPILE" ] && echo "All binary files are compiled and ready!"
}

build_image() {
  printf "Building image for $IMG_NAME from dockerfile ... "
  docker build --tag $IMG_NAME . > $TERM_OUT
  printf %b\\n "done."
}

remove_image() {
  printf "Removing existing image ... "
  docker image rm $IMG_NAME > /dev/null 2>&1
  printf %b\\n "done."
}

create_network() {
  printf "Creating network $NET_NAME ... "
  docker network create $NET_NAME > /dev/null 2>&1;
  printf %b\\n "done."
}

stop_container() {
  ## Check if previous container exists, and remove it.
  printf "Stopping existing container ... "
  docker container stop $SRV_NAME > /dev/null 2>&1
  docker container rm $SRV_NAME > /dev/null 2>&1
  printf %b\\n "done."
}

wipe_data() {
  printf "Purging existing data volume ... "
  docker volume rm $DAT_NAME > /dev/null 2>&1
  printf %b\\n "done."
}

###############################################################################
# Main
###############################################################################

main() {
  ## Start container in runtime configuration.
  echo "Starting container for $SRV_NAME in $RUN_MODE mode ..."
  docker run -t \
    --name $SRV_NAME \
    --hostname $SRV_NAME \
    --network $NET_NAME \
    --mount type=bind,source=$(pwd)/share,target=/share \
    --mount type=volume,source=$DAT_NAME,target=/data \
  $RUN_FLAGS $MOUNTS $PORTS $ENV_STR $ARGS_STR $IMG_NAME:latest
}

###############################################################################
# Script
###############################################################################

set -E

## Parse arguments.
for arg in "$@"; do
  case $arg in
    -h|--help)         usage;                            exit 0 ;;
    -C|--compile)      COMPILE=1 check_binaries;         exit 0 ;;
    -b|--build)        BUILD=1;                          shift  ;;
    -r|--rebuild)      REBUILD=1;                        shift  ;;
    -w|--wipe)         WIPE=1;                           shift  ;;
    -i|--interactive)  DEVMODE=1;                        shift  ;;
    -v|--verbose)      TERM_OUT="/dev/tty";              shift  ;;
    -d=*|--domain=*)   DOMAIN=${arg#*=};                 shift  ;;
    -M=*|--mount=*)    ADD_MOUNTS=${arg#*=};             shift  ;;
    -P=*|--ports=*)    ADD_PORTS=${arg#*=};              shift  ;;
    -p=*|--peers=*)    add_arg "PEER_LIST=${arg#*=}";    shift  ;;
    -c=*|--channels=*) add_arg "CHAN_LIST=${arg#*=}";    shift  ;;
    -f=*|--faucet=*)   add_arg "USE_FAUCET=${arg#*=}";   shift  ;;
    -m|--mine)         add_arg "MINE_NODE=DEFAULT";      shift  ;;
    -m=*|--mine=*)     add_arg "MINE_NODE=${arg#*=}";    shift  ;;
    -t|--tor)          add_arg "TOR_NODE=1";             shift  ;;
  esac
done

## If no name argument provied, display help and exit.
if [ -z "$1" ]; then usage && exit 0; else TAG="$1"; fi

## Set default variables.
if [ -z "$DOMAIN" ]; then DOMAIN="$DEFAULT_DOMAIN"; fi

## Define naming scheme.
IMG_NAME="$DOMAIN.img"
NET_NAME="$DOMAIN.net"
SRV_NAME="$TAG.$DOMAIN.node"
DAT_NAME="$TAG.$DOMAIN.data"

## Check that required binaries exist.
check_binaries()

## If rebuild is declared, remove existing image.
if image_exists && [ -n "$REBUILD" ]; then remove_image; fi

## If no existing image is present, build it.
if ! image_exists || [ -n "$BUILD" ]; then build_image; fi

## Set run mode of container.
if [ -n "$DEVMODE" ]; then
  DEV_MOUNT="type=bind,source=$(pwd)/run,target=/root/run"
  RUN_MODE="interactive"
  RUN_FLAGS="-i --rm --entrypoint bash --mount $DEV_MOUNT -e DEVMODE=1"
else
  RUN_MODE="detached"
  RUN_FLAGS="-d --restart unless-stopped"
fi

## Create peers path if missing.
if [ ! -d "share" ]; then mkdir share; fi

## If no existing network exists, create it.
if ! network_exists; then create_network; fi

## If additional mount points are specified, build a mount string.
if [ -n "$ADD_MOUNTS" ]; then for point in `echo $ADD_MOUNTS | tr ',' ' '`; do
  src=`printf $point | awk -F ':' '{ print $1 }'`
  dest=`printf $point | awk -F ':' '{ print $2 }'`
  if [ -z "$(echo $point | grep -E '^/')" ]; then prefix="$(pwd)/"; fi
  MOUNTS="$MOUNTS --mount type=bind,source=$prefix$src,target=$dest"
done; fi

## If additional ports are specified, build a port string.
if [ -n "$ADD_PORTS" ]; then for port in `echo $ADD_PORTS | tr ',' ' '`; do
  PORTS="$PORTS -p $port:$port"
done; fi

## Convert environment file into string.
if [ -e "$ENV_PATH" ]; then ENV_STR=`read_env $ENV_PATH`; fi

## Make sure to stop any existing container.
if container_exists; then stop_container; fi

## Purge data volume if flagged.
if volume_exists && [ -n "$WIPE" ]; then wipe_data; fi

## Call main container script.
main

## If container is detached, connect to it.
if [ "$RUN_MODE" = "detached" ]; then
echo "================ TEST ======================="
  #docker logs -f "$SRV_NAME"
  printf "
=============================================================================
  Initialization complete. Use below command to access container:
  docker exec -it "$SRV_NAME" bash
=============================================================================
"
  docker exec -it $SRV_NAME bash
fi