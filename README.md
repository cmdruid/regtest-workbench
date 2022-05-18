# Regtest Node

A containerized development stack of Tor, Bitcoin Core and Lightning Core.

## How to use

*Make sure that docker is installed, and you are part of docker group.*

```
git clone *this repository url*
cd regtest-node

./start.sh --help
```

The start script will launch the included Dockerfile inside a container, copy files from `config` and `build/out`, mount the `run` and `share` folders, install any dependencies and setup the environment.

If binaries are not available in `build/out`, then the script will build each binary from source, using the included files in `build/dockerfiles`.

When finished, you will be given a terminal prompt inside the container. The `share` folder will also be populated with connection information for each system running in the stack.

### /build

The start script will look for system binaries in `out` directory, and if not available, will build them from source using files in the `dockerfile` folder.

### /config

These files are used to configure the container environment and each system in the stack. Feel free to modify these files, then run `./start.sh` with the `--build` or `--rebuild` flag. The script will update your Dockerfile with your latest changes.

### /doc

Any documentation will be stored in this folder. More documentation coming soon!

### /run

This folder contains the main `entrypoint.sh` script, plus all other scripts used to setup the container. Scripts placed in `lib` are available in the container's PATH. Scripts placed in `startup` are executed in alphanumeric order when `entrypoint.sh` is run. Additional scripts are stored in `utils`.

### /share

Each node will create their own directory in this folder (named after their `HOSTNAME`), and store any configuration files used to connect to the container and its services.

## Contribution

All contributions are welcome! If you have any questions, feel free to send me a message or submit an issue.

## Tools

LNURL Decoder
https://lnurl.fiatjaf.com/codec
## Resources

Bitcoin Developer Reference
https://developer.bitcoin.org/reference/index.html

Core Lightning Documentation
https://lightning.readthedocs.io

Core Lighting REST API Docs
https://github.com/Ride-The-Lightning/c-lightning-REST#apis

Sparko Client
https://github.com/fiatjaf/sparko-client

Pyln-client
https://github.com/ElementsProject/lightning/tree/master/contrib/pyln-client

clightningjs
https://github.com/lightningd/clightningjs

Flask Documentation
https://flask.palletsprojects.com/en/2.1.x

Node.js Documentation
https://nodejs.org/api
