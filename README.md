# Regtest Node

A containerized stack of Tor / Bitcoin / Ligtning, plus a suite of development tools. Designed for rapid prototyping, so you can deploy your next project lightning-quick!

## How to use

*Make sure that docker is installed, and you are part of docker group.*

To quickly spin up a test network of three nodes:

```
git clone *this repository url* && cd regtest-node

## A quick tutorial is built into the help screen.
./start.sh --help

## Your main node. Seed the blockchain and mine blocks.
./start.sh --seed --mine master

## Meet Alice, who connects to master and requests funding.
./start.sh --faucet=master --peer=master alice

## Meet Bob, also funded by master, who connects to Alice and opens a channel.
./start/sh --faucet=master --peer=alice --channel=alice bob

... repeat for as many nodes as your like!
```
Each node is designed to automatically connect with peers (Bitcoin and Lightning), request funds from a designated node, open channels, and auto-balance those channels.

Nodes with the `--seed` flag will get your chain started by auto-generating blocks up to a certain height. Block rewards require 100 blocks to mature, so the default height is 150. You only need to use this flag once, and it should be on your first node. 

*You should also use your seed node as your facuet, since those blocks rewards will make it filthy rich.*

Nodes with the `--mine` flag will scan the mempool and auto-mine blocks in order to settle transactions quickly (can also be configured to mine on a schedule).

Nodes with the `--tor` flag will auto-magically peer and route with other nodes that have Tor enabled, no extra configuration required! Any node with tor enabled can still accept peering on both networks, but will prefer tor.

*This project is designed to automate completely over tor, meaning you can build a regtest network across multiple networks and machines!*

All required authentication keys and credentials are generated and stored in the `/share` folder for easy access (for you and your nodes). The files are namespaced and refreshed each time you restart a given node, so feel free to `--wipe` a node's data store on a frequent basis.

Each node launches with a simple web-wallet (provided by sparko) to manage invoices and test payments between nodes. You also have quick access to `bitcoin-cli` and `lightning-cli` from the terminal.

The `./run/entrypoint.sh` start script included with each node is designed to be re-run repeatedly from the terminal, in order to refresh configurations and resolve any issues during a node's startup process.

All nodes ship with Flask and Nodejs included, plus a core library of tools for connecting to the underlying Bitcoin / Lightning daemons. *Work in progress* Check out the example projects located in `contrib/examples`, so you can jump into web/app development right away!

## How it works

The start script will launch the included Dockerfile inside a container, copy files from `config` and `build/out`, mount the `run` and `share` folders, install any dependencies and setup the environment.

If binaries are not available in `build/out`, then the script will build each binary from source, using the included files in `build/dockerfiles`.

When finished, you will be given a terminal prompt inside the container. The `share` folder will also be populated with connection information for each system running in the stack.

## What everything does

### /build

The start script will look for system binaries in `out` directory, and if not available, will build them from source using files in the `dockerfile` folder.

### /config

These files are used to configure the container environment and each system in the stack. Feel free to modify these files, then run `./start.sh` with the `--build` or `--rebuild` flag. The script will update your Dockerfile with your latest changes.

### /contrib

*Work in progress*

### /doc

Any documentation will be stored in this folder. More documentation coming soon!

### /run

This folder contains the main `entrypoint.sh` script, plus all other scripts used to setup the container. Scripts placed in `lib` are available in the container's PATH. Scripts placed in `startup` are executed in alphanumeric order when `entrypoint.sh` is run. Additional scripts are stored in `utils`.

### /share

Each node will create their own directory in this folder (named after their `HOSTNAME`), and store any configuration files used to connect to the container and its services.

## Development

*Work in progress. Will write an introduction to interactive mode and how to hack the project on your own!*

## Contribution

All contributions are welcome! If you have any questions, feel free to send me a message or submit an issue.

## Tools

LNURL Decoder
https://lnurl.fiatjaf.com/codec

## Resources

Bitcoin Developer Reference
A great resource for documentation on Bitcoin's RPC interface, and other technical details.
https://developer.bitcoin.org/reference/index.html

Core Lightning Documentation
The go-to resource for Core Lightning's RPC interface.
https://lightning.readthedocs.io

Core Lighting REST API Docs
Documentation for the REST interface that is provided by the RTL team.
https://github.com/Ride-The-Lightning/c-lightning-REST#apis

Sparko Client
Incredibly useful web-RTC interface and web-client for Core Lightning.
https://github.com/fiatjaf/sparko-client

Pyln-client
The main library for interfacing with Core Lightning over RTC. Very powerful.
https://github.com/ElementsProject/lightning/tree/master/contrib/pyln-client

clightningjs
The javascript version of an RTC interface and library for Core Lightning.
https://github.com/lightningd/clightningjs

Flask Documentation
The go-to resource for documentation on using Flask.
https://flask.palletsprojects.com/en/2.1.x

Node.js Documentation
The go-to resource for documentation on using Nodejs.
https://nodejs.org/api
