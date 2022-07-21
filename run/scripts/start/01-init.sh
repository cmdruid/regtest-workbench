#!/usr/bin/env bash
## Startup script for init.

set -E

###############################################################################
# Environment
###############################################################################

###############################################################################
# Script
###############################################################################

templ banner "Init Configuration"

## Purge existing shared files.
if [ -d "$SHAREPATH/$HOSTNAME" ]; then
  printf "Purging existing share configurations"
  rm -r $SHAREPATH/$HOSTNAME && templ ok
fi

## Create shared path.
if [ ! -d "$SHAREPATH/$HOSTNAME" ]; then
  printf "Creating share path"
  mkdir -p "$SHAREPATH/$HOSTNAME" && templ ok
fi

## If tor enabled, call tor startup script.
if [ -n "$TOR_NODE" ]; then sh -c $LIBPATH/start/onion-start.sh; fi

## Install lightning binaries
REPOPATH="/root/run/repo/lightning"
if [ -z "$(which lightningd)" ]; then
  [ ! -d "$REPOPATH/out" ] \
    && printf "Creating $REPOPATH/out ...\n" \
    && mkdir -p $REPOPATH/out
  [ ! -d "$REPOPATH/out/bin" ] \
    && printf "Building clightning binaries ...\n" \
    && cd $REPOPATH \
    && ./configure --prefix=out --enable-developer --enable-experimental-features \
    && make && make install
  printf "Installing clightning binaries ..."
  cp -r $REPOPATH/out/* /usr/local
  [ -n "$(which lightningd)" ] && templ ok || templ fail
fi