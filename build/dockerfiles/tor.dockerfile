FROM debian:bullseye-slim AS build-stage

ARG BIN_NAME="tor"

ENV BUILD_BRANCH="0.4.7.8"

ENV REPO_URL="https://dist.torproject.org"
ENV FILENAME="${BIN_NAME}-${BUILD_BRANCH}.tar.gz"

ENV PATH="/root/.local/bin:$PATH"
ENV TAR_NAME="$BIN_NAME-$BUILD_BRANCH"

## Keys provided by unofficial github page.
## https://github.com/torproject/tor
ENV KEYS="\
  514102454D0A87DB0767A1EBBE6A0531C18A9179,\
  B74417EDDF22AC9F9E90F49142E86A2A11F48D36,\
  2133BC600AB133E1D826D173FE43009C4607B1FB\
"

ENV SERVERS="keyserver.ubuntu.com, keys.openpgp.org, keyserver.pgp.com"

## Install dependencies.
RUN apt-get update && apt-get install -y \
  build-essential curl gnupg libevent-dev libssl-dev pkg-config python3 zlib1g zlib1g-dev

## Prepare directories.
RUN mkdir -p /root/bin && mkdir -p /root/out

WORKDIR /root

## Download gpg key from keyservers.
RUN echo "Importing gpg keys from file..."
RUN for key in $(echo $KEYS | tr ',' '\n'); do \
    for server in $(echo $SERVERS | tr ',' '\n'); do \
        echo "Verifying key $key with server: $server" \
        && if $(gpg --batch --keyserver "$server" --recv-keys "$key"); then break; fi \
    ; done \
; done

## Download source code and checksums.
RUN curl -SLO "$REPO_URL/$FILENAME"
RUN curl -SLO "$REPO_URL/$FILENAME.sha256sum"
RUN curl -SLO "$REPO_URL/$FILENAME.sha256sum.asc"

## Verify integrity of files.
RUN gpg --verify $FILENAME.sha256sum.asc $FILENAME.sha256sum
RUN echo $(cat $FILENAME.sha256sum) | sha256sum -c -

## Extract source code archive.
RUN tar -xf $FILENAME

## Configure and build binary file from source.
RUN cd $(basename -s .tar.gz $FILENAME) \
  && ./configure \
  && make && make DESTDIR=/root/bin install

## Prepare binary as tarball.
RUN tar -czvf /root/out/$TAR_NAME.tar.gz -C /root/bin usr

## Extract binary archive.
FROM scratch AS export-stage
COPY --from=build-stage /root/out /