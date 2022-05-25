FROM debian:bullseye-slim

## Install dependencies.
RUN apt-get update && apt-get install -y \
  curl git iproute2 jq libevent-dev libsodium-dev lsof man \
  netcat openssl procps python3 python3-pip qrencode socat \
  xxd neovim

## Copy over binaries.
COPY build/out/* /tmp/bin/

WORKDIR /tmp

## Unpack and install binaries.
RUN for file in /tmp/bin/*; do \
  if ! [ -z "$(echo $file | grep .tar.)" ]; then \
    echo "Unpacking $file to /usr ..." \
    && tar --wildcards --strip-components=1 -C /usr -xf $file \
  ; else \
    echo "Moving $file to /usr/bin ..." \
    && chmod +x $file && mv $file /usr/bin/ \
  ; fi \
; done

## Clean up temp files.
RUN rm -rf /tmp/* /var/tmp/*

## Uncomment this if you also want to wipe all repository lists.
#RUN rm -rf /var/lib/apt/lists/*

## Install python modules
RUN pip3 install Flask pyln-client pyln-proto bitstring

## Install Node.
RUN curl -fsSL https://deb.nodesource.com/setup_17.x | bash - && apt-get install -y nodejs

## Install node packages.
RUN npm install -g npm yarn

## Install sparko binary
RUN mkdir -p /root/.lightning/plugins \
  && curl https://github.com/fiatjaf/sparko/releases/download/v2.9/sparko_linux_amd64 \
  -fsL#o /root/.lightning/plugins/sparko \
  && chmod +x /root/.lightning/plugins/sparko

## Install RTL REST API.
# RUN mkdir -p /root/.lightning \
#   && cd /root/.lightning \
#   && git clone https://github.com/Ride-The-Lightning/c-lightning-REST.git \
#   && cd cl-rest && npm install

WORKDIR /root

## Configure user account for Tor.
# RUN addgroup tor \
#   && adduser --system --no-create-home tor \
#   && adduser tor tor \
#   && chown -R tor:tor /var/lib/tor /var/log/tor

## Copy configuration and run environment.
COPY config /root/config/
COPY run /root/run/

## Add bash aliases to bashrc.
RUN alias_file="~/config/.bash_aliases" \
  && printf "if [ -e $alias_file ]; then . $alias_file; fi\n\n" >> /root/.bashrc

## Make sure scripts are executable.
RUN chmod +x /root/run/bin /root/run/lib /root/run/startup /root/run/entrypoint.sh

## Configure additional paths.
ENV PATH="/root/run/bin:/root/.local/bin:$PATH"
#ENV PYPATH="/root/run/pylib:$PYPATH"

ENTRYPOINT [ "/root/run/entrypoint.sh" ]
