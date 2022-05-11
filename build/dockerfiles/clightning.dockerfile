FROM debian:bullseye-slim AS build-stage

ARG BIN_NAME

ENV BUILD_TARGET="x86_64-pc-linux-gnu"
ENV BUILD_BRANCH="v0.10.2"

ENV REPO_URL="https://github.com/ElementsProject/lightning.git"
ENV REPO_DIR="lightning"

ENV PATH="/root/.local/bin:$PATH"
ENV TAR_NAME="$BIN_NAME-$BUILD_BRANCH-$BUILD_TARGET"

## Prepare directories.
RUN mkdir -p /root/bin && mkdir -p /root/out

## Install dependencies.
RUN apt-get update && apt-get install -y \
  autoconf automake build-essential git libtool libgmp-dev libsqlite3-dev \
  pkg-config python3 python3-pip net-tools zlib1g-dev libsodium-dev gettext vim

RUN pip3 install --upgrade pip
RUN pip3 install poetry

## Download source from remote repository.
RUN cd /root \
  && git clone $REPO_URL --branch $BUILD_BRANCH --single-branch

## Configure, compile and build binaries from source.
WORKDIR /root/$REPO_DIR

RUN pip3 install -r requirements.lock
RUN ./configure --prefix=/root/bin/$TAR_NAME
RUN make && make install

## Prepare binary as tarball.
RUN ls /root/bin | grep $TAR_NAME
RUN tar -czvf /root/out/$TAR_NAME.tar.gz -C /root/bin $TAR_NAME

## Extract binary archive.
FROM scratch AS export-stage
COPY --from=build-stage /root/out /