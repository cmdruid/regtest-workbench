#!/bin/sh
## Build script template. See accompanying Dockerfile for more build options.

###############################################################################
# Environment
###############################################################################

PATH_NAME=`dirname $1`
FILE_NAME=`basename $1`
BASE_NAME=`basename -s .dockerfile $1`
DEFAULT_BUILDPATH="$(pwd)"

###############################################################################
# Methods
###############################################################################

usage() {
  printf "
  Compile a binary using the provided docekrfile, and save to /out directory.
  
  Usage: $0 example.dockerfile (or files/example.dockerfile)
  \n"
}

###############################################################################
# Script
###############################################################################

set -e

## Set default build path.
if [ -z "$BUILDPATH" ]; then BUILDPATH=$DEFAULT_BUILDPATH; fi

## Check input argument.
if [ -z "$1" ] ; then
  echo "Error: You must specify a Dockerfile to use!" && usage && exit 1
elif [ "$1" = "--help" ]; then
  usage && exit 0
elif [ ! -e "$1" ]; then
  echo "Error: $1 does not exist! Are you providing the right path?" && usage && exit 1
else
  echo "Starting builder using $FILE_NAME ... "
fi

## If out/ path does not exist, create it.
if [ ! -d "$BUILDPATH/out" ]; then
  mkdir "$BUILDPATH/out"
fi

## If previous docker image exists, remove it.
if [ ! -z "$(docker image ls | grep $FILE_NAME)" ]; then
  docker image rm $FILE_NAME
fi

## Begin building image.
DOCKER_BUILDKIT=1 docker build \
  --tag $FILE_NAME \
  --output type=local,dest=$BUILDPATH/out \
  --file $PATH_NAME/$FILE_NAME \
$2 $BUILDPATH
