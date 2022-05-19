# Regtest Node

A containerized stack of Bitcoin and Ligtning, plus a suite of development tools. Prototype and deploy your next project with lightning speed!

## How to Use

> *Note: Make sure that docker is installed, and your user is part of the docker group.*

To spin up a basic network of three nodes:

```shell
## Clone this repository, and make it your working directory.
git clone "this repository url" && cd regtest-node

## Compiles all the binaries that we will need. May take a while!
./start.sh --compile

## Your first (and main) node. Seeds the blockchain and mines blocks.
./start.sh --seed --mine master

## Meet Alice, who connects to master and requests funding.
./start.sh --faucet=master --peers=master alice

## Meet Bob, also funded by master, who connects to Alice and opens a channel.
./start/sh --faucet=master --peers=alice --channels=alice bob

## ... repeat for as many nodes as you like!

## A quick tutorial is also built into the help screen.
./start.sh --help
```
Each node is designed to automatically connect with peers (*on bitcoin and lightning*), request funds from a designated node, open channels, and auto-balance those channels. All argument flags are optional. The final argument will designate your node with a name tag.

Use the `--seed` flag with your first node in order to initiate the chain. The seed node will auto-generate blocks up to a certain height. Block rewards require 100 blocks to mature, so the default height is 150. You only need to use this flag once.

The `--mine` flag will configure a node to watch the mempool, then auto-mine blocks when it sees an unconfirmed transaction. The default poll time is 2 seconds, in order to process transactions quickly. If you wish to deploy multiple miners, use a much longer poll time (*or suffer from chain splits!*), or configure a fixed block schedule. ~~See [/doc/man.md](doc/man.md) for more info.~~

The `--peers` and `--channels` flags will intsruct nodes on whom to peer and open channels with. These flags accept a comma-separated list of nametags (*e.x alice,bob,carol*). The `--faucet` flag will instruct your node to request funding from another node. Nodes are smart enough to configure their own wallets, negotiate funding, and balance their channels accordingly!

> Tip: *Use your seed node as the main faucet, since the initial block rewards will make it filthy rich! Miners may also generate blocks in order to procure funds if their wallet balance is low.*

Nodes with the `--tor` flag will auto-magically setup onion routing and peer with other tor-enabled nodes, no extra configuration required. This flag will also make the endpoints on a given node available as (v3) hidden services. Tor nodes can still communicate with non-tor nodes, but will default to using tor when available.

All the pertinent settings, keys and credentials for running nodes are namespaced and stored in the `/share` folder. Each node will mount and scan this folder in order to peer and communicate with other nodes. Files for a given node are refreshed when you restart that node, so feel free to modify a node's settings and data on a frequent basis!

> Note: *This project is designed to automate completely over tor, using the `/share` folder. You can copy / distribute these files onto other machines and build a regtest network across multiple networks!*

Each node launches with a simple web-wallet for managing invoices and test payments (*provided by sparko*). Nodes will print their local address and login credentials to the console upon startup. You can also manage payments easily using `bitcoin-cli` and `lightning-cli`.

The `./run/entrypoint.sh` startup script is the heart of each node, and is designed to be re-run as many times as you like. If you have a node with issues, try entering the console to run the script manually. The entrypoint script is very informative, and will help refresh configurations, restart services, or diagnose / resolve issues that crop up during the startup process.

> Tip: *Use the `--interactive` flag to enter a node's console before the entrypoint script is run. This flag will also mount the /run folder directly, allowing you to hack / modify the source code for this project in real-time. Don't forget to use version control. ;-)*

All nodes ship with Flask and Nodejs included, plus a core library of tools for connecting to the underlying Bitcoin / Lightning daemons. *Work in progress* Check out the example projects located in `contrib/examples` if you want to jump into web/app development right away!

## Repository Overview

### \#\# ./build

This path contains the build script, related dockerfiles, and compiled binaries. When you run the `start.sh` script, it will fist scan the `build/dockerfiles` and `build/out` path in order to compare files. If a binary appears to be missing, the start script will then call the build script (with the related dockerfile), and request to build the missing binary from source.

If you have just cloned this repositry, it's best to run `./start.sh --compile` as a first step, so that launching your first node doesn't force you to compile everything at once.

Any compressed binaries located in `build/out` are copied and installed at build time, so feel free to add your own. The script recognizes tar.gz compression, and will strip the first folder before unpacking into `/usr`, so make sure to pack your binaries accordingly.

You can also add your own dockerfiles, or modify the existing ones in order to try different builds and versions. For adding custom dockerfiles, make sure your dockerfile produces a compiled binary with a matching substring, so the start script can correctly determine which baineies are present / missing.

### \#\# ./config

These are the configuration files used by the main services in the stack. The entire config folder is copied at build time, located at `/root/config` in the image. Feel free to modify these files or add your own, then use `--build` or `--rebuild` to refresh the image when starting a container.

### \#\# ./contrib

*Work in progress. Will contain example templates and demos for building bitcoin / lightining connected apps.*

### \#\# ./doc

Documentation will be stored in this folder. More documentation coming soon!

### \#\# ./run

This folder contains the main `entrypoint.sh` script, libraries and tools, plus all other scripts used to manage services in the stack. 

- Scripts placed in `bin` and `lib` are available from the container's PATH (`pylib` for PYPATH). 
- Scripts placed in `startup` are executed in alpha-numeric order when `entrypoint.sh` is run. 
- Projects placed in `plugins` are loaded by lightningd at startup (*your main script must match the folder name*). 
- All other scripts are organized into `util`.

The entire run folder is copied at build time, located at `/root/run` in the image. Feel free to modify these files or add your own, then use `--build` or `--rebuild` to refresh the image when starting a container. When starting a container in `--interactive` mode, this folder is mounted directly, with files modified in real-time.

### \#\# ./share

Each node will mount this folder at runtime, then create and manage their own folder and configuration data. Each folder is namespaced after a node's hostname, and used by other nodes in order to peer and connect to its services. These files are constantly created and destroyed by their respective nodes, so that the data remains fresh and accurate.

## Development

*Work in progress. Will write an introduction to interactive mode and how to hack the project on your own!*

## Contribution

All contributions are welcome! If you have any questions, feel free to send me a message or submit an issue.

## Tools

**LNURL Decoder**  
https://lnurl.fiatjaf.com/codec

## Resources

**Bitcoin Developer Reference**  
A great resource for documentation on Bitcoin's RPC interface, and other technical details.  
https://developer.bitcoin.org/reference/index.html

**Core Lightning Documentation**  
The go-to resource for Core Lightning's RPC interface.  
https://lightning.readthedocs.io

**Core Lighting REST API Docs**  
Documentation for the REST interface that is provided by the RTL team.  
https://github.com/Ride-The-Lightning/c-lightning-REST#apis

**Sparko Client**  
Incredibly useful web-RTC interface and web-client for Core Lightning.  
https://github.com/fiatjaf/sparko-client

**Pyln-client**  
The main library for interfacing with Core Lightning over RTC. Very powerful.  
https://github.com/ElementsProject/lightning/tree/master/contrib/pyln-client

**clightningjs**  
The javascript version of an RTC interface and library for Core Lightning.  
https://github.com/lightningd/clightningjs

**Flask Documentation**  
The go-to resource for documentation on using Flask.  
https://flask.palletsprojects.com/en/2.1.x

**Node.js Documentation**  
The go-to resource for documentation on using Nodejs.  
https://nodejs.org/api
