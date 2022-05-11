FROM debian:bullseye-slim AS build-stage

ARG BIN_NAME="bitcoind"

ENV BUILD_TARGET="x86_64-pc-linux-gnu"
ENV BUILD_BRANCH="23.x"

ENV REPO_URL="https://github.com/bitcoin/bitcoin.git"
ENV REPO_DIR="bitcoin"

ENV DEPS_ARGS="NO_QT=1 NO_QR=1 NO_BDB=1 NO_UPNP=1 NO_NATPMP=1 ALLOW_HOST_PACKAGES=1"
ENV CONF_ARGS="--disable-tests --disable-bench"
ENV MAKE_ARGS=""

ENV PATH="/root/.local/bin:$PATH"
ENV TAR_NAME="$BIN_NAME-$BUILD_BRANCH-$BUILD_TARGET"

## Prepare directories.
RUN mkdir -p /root/bin /root/out

## Install dependencies
RUN apt-get update && apt-get install -y \
  autoconf automake binutils-gold bison bsdmainutils cmake curl git \
  g++-multilib libtool make pkg-config python3 patch sqlite3 wget

## Download source from remote repository.
RUN cd /root && git clone $REPO_URL --branch $BUILD_BRANCH --single-branch

WORKDIR /root/$REPO_DIR

## Configure, compile and build binaries from source.
RUN make -C depends $DEPS_ARGS
RUN ./autogen.sh
RUN CONFIG_SITE=$PWD/depends/$BUILD_TARGET/share/config.site \
  ./configure $CONF_ARGS
RUN make HOST=$BUILD_TARGET $MAKE_ARGS
RUN make DESTDIR=/root/bin install

## Prepare binary as tarball.
RUN tar -czvf /root/out/$TAR_NAME.tar.gz -C /root/bin usr

## Extract binary archive.
FROM scratch AS export-stage
COPY --from=build-stage /root/out /