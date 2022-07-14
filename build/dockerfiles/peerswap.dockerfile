FROM golang:1.19rc1-bullseye AS build-stage

ARG BIN_NAME="peerswap"

# ENV BUILD_TARGET="x86_64-pc-linux-gnu"
# ENV BUILD_BRANCH="v0.11.2"

ENV REPO_URL="https://github.com/cmdruid/peerswap.git"
ENV REPO_DIR="peerswap"

ENV PATH="/root/.local/bin:$PATH"
ENV TAR_NAME="$BIN_NAME"

# $BUILD_BRANCH-$BUILD_TARGET"

## Prepare directories.
RUN mkdir -p /root/bin && mkdir -p /root/out

## Install dependencies.
RUN apt-get update && apt-get install -y \
  autoconf automake build-essential git libtool \
  pkg-config net-tools vim

## Download source from remote repository.
RUN cd /root \
  && git clone $REPO_URL $REPO_DIR

## Configure, compile and build binaries from source.
WORKDIR /root/$REPO_DIR

RUN make cln-release
RUN cp peerswap-plugin /root/out/peerswap

## Extract binary archive.
FROM scratch AS export-stage
COPY --from=build-stage /root/out /