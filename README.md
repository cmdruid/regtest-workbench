# Regtest Workbench

A robust, featured-rich development environment for building on-top of Bitcoin and Lightning.

Launch multiple Bitcoin / Lightning nodes, and watch them form an automated network of miners, validators, and lightning channels. Each node contains an interactive terminal, web wallet, and suite of development tools.

Also included in each node:
 - Multiple interfaces to connect with: Spark, REST, LightningRPC, and more.
 - Full Tor (V3) services support for all interfaces (plus peering!).
 - Support for latest version of Zeus wallet via REST and sparko connect.
 - Fully automated opening and balancing of channels between nodes.
 - Automated loading and hot-loading of plugins for Core Lightning.
 - Multiple launch configurations: safe mode, dev mode, and headless mode.
 - Coming soon: transaction / invoice traffic generation, native websocket interface.

Everything is configured out of the box. Simply open up a node port and connect your application. Prototype and deploy your next project with lightning speed!

## How to Use

> *Note: Make sure that docker is installed, and your user is part of the docker group.*

To spin up a basic network of three nodes:

```shell
## Clone this repository, and make it your working directory.

git clone "https://github.com/cmdruid/regtest-workbench.git"
cd regtest-workbench

## Compiles all the binaries that we will need. May take a while!
./workbench.sh compile

## Your first (and main) node. Seeds the blockchain and mines blocks.
./workbench.sh start master --miner

## Meet Alice, who connects to master and requests funding.
./workbench.sh start alice --faucet master

## Meet Bob, also funded by master, who peers and opens a channel with Alice.
./workbench.sh start bob --faucet master --channels alice

## Meet Carol, who likes to use shorter commands, and start in headless mode.
./workbench.sh start carol -f master -c alice,bob --headless

## ... repeat for as many nodes as you like!

## A detailed guide is also built into the help screen.
./workbench.sh --help
```
Based on the above configuration, each node will automatically connect to their designated peers, request funds from a faucet, and open payment channels. The `start` keyword designates your node with a name tag.

Use the `--miner` flag with your first node in order to initiate the chain. Your miner will detect a new chain, then auto-generate blocks up to a certain height. Block rewards require at least 100 blocks to mature, so the default starting height is 150.

By default, Your miner is configured to watch the mempool, then auto-generate blocks when it sees an unconfirmed transaction. The default poll time is 2 seconds, so transactions should confirm quickly. If you wish to deploy multiple miners, use a different configuration that avoids chain splits.

The format for configuring each miner is `--miner=poll-time,interval-time,fuzz-amount` in seconds. For example, the configuration `0,10,20` will disable polling, schedule a block every 10 seconds, plus a random value between 1 and 20 seconds.

The `--peers` flag will instruct nodes on whom to peer with, and share transactions / blocks.
The `--faucet` flag will instruct your node to peer and request funds from another node.
The `--channels` flag will instruct your node to peer and open channels with another node.

By default, nodes will request a balance of 10 BTC, and open channels with a balance of 5 million sats (split 50/50 between parties). You can modify these settings (and much more) by editing the `.env.sample` file at the root of this repo.

The `--peers` and `--channels` flags accept a comma-separated list of nametags (*e.x alice,bob,carol*).  Nodes are smart enough to configure their own wallets, negotiate funding, and balance channels!

> Tip: *Use your initial miner node as your main faucet, since the block rewards will have made him filthy rich! Miners may also generate more blocks in order to procure funds if their wallet balance is low.*

Nodes with the `--tor` flag will auto-magically use onion routing when peered with other tor-enabled nodes, no extra configuration required. This flag will also configure a node's endpoints as (v3) hidden services. Tor nodes can still communicate with non-tor nodes, but will default to using tor when available (unless given the `--local` flag).

All pertinent settings, keys and credentials for a node is namespaced and stored in the `/share` folder. Nodes will use this folder in order to peer and communicate with other nodes. The files for each node are refreshed when you restart that node, so feel free to muck with the settings on a frequent basis!

> Note: *Nodes are designed to work completely over tor, using the `/share` folder. You can copy / distribute a node's shared files onto other machines and build a regtest network across the web!*

Each node launches with a simple web-wallet for managing invoices and test payments (*provided by sparko*). Nodes will print their local address and login credentials to the console upon startup. You can also manage payments easily using `bitcoin-cli` and `lightning-cli`.

> Tip: *The short-hand `bcli` and `lcli` are also available. Check out the `config/.bash_aliases` file for more handy aliases!*

Use the `--devmode` flag to enter a node's console before the startup script is run. This flag will also mount the /run folder directly, allowing you to hack / modify the source code for this project in real-time. Don't forget to use version control. ;-)

> Tip: *If you have a node suffering from issues, run the `node-start` command within the node's terminal. It is the main start script, and designed to help refresh configurations, restart services, or diagnose / resolve issues that crop up during the startup process. If all else fails, restart the node using the`--wipe` flag to erase its persistent storage, and give your node a fresh start!*

All nodes ship with Flask and Nodejs included, plus a core library of development tools. Check out the example projects located in `contrib/examples` if you want to jump into web/app development right away!

> *FYI contrib/examples is sparse at the moment. More demo projects will be added mid-June. Please contact me if you would like to help contribute!*

## Repository Overview

### \#\# ./build

This path contains the build script, related dockerfiles, and compiled binaries. When you run the `workbench.sh` script, it will fist scan the `build/dockerfiles` and `build/out` path in order to compare files. If a binary appears to be missing, the start script will then call the build script (with the related dockerfile), and request to build the missing binary from source. Compiled binaries are then copied `build/out`.

If you have just cloned this repositry, it's best to run `./workbench.sh compile` as a first step, so that launching your first node doesn't force you to compile everything at once.

All files located in `build/out` are copied over to the main docker image and installed at build time, so feel free to include any binaries you wish! The script recognizes tar.gz compression, and will strip the first folder before unpacking into `/usr`, so make sure to pack your files accordingly.

You can also add your own `build/dockerfiles`, or modify the existing ones in order to try different builds and versions. If you add a custom dockerfile, make sure it also names the binary with a matching substring, so the start script can correctly determine if your binary is present / missing.

### \#\# ./config

These are the configuration files used by the main services in the stack. The entire config folder is copied at build time, to `/root/config` in the image. Feel free to modify these files or add your own, then use `--build` or `--rebuild` to refresh the image when starting a container.

The `.bash_aliases` file is also loaded upon startup, feel free to use it to customize your environment!

### \#\# ./contrib

*Work in progress. Will contain example templates and demos for building bitcoin / lightining connected apps.*

### \#\# ./doc

Documentation will be stored in this folder. More documentation coming soon!

### \#\# ./run

This folder contains the main `entrypoint.sh` script, libraries and tools, plus all other scripts used to manage services in the stack.

- Most of the source code for this project is located in `lib`.
- Files in `lib\bin` are available in the container's PATH.
- Files in `lib\pylib` are available in the container's PYPATH.
- Files in `plugins` are loaded by lightningd at startup (*main script must match folder name*).
- Scripts in `startup` are executed in alpha-numeric order when `node-start` is run.

The entire run folder is copied at build time, located at `/root/run` in the image. Feel free to modify these files or add your own, then use `--build` or `--rebuild` to refresh the image when starting a container. When a container is started in `--devmode`, the `run` folder is mounted directly, and files are modified in real-time.

### \#\# ./share

Each node will mount this folder on startup, then use it as a shared repository for providing their own configuration data. Each folder is namespaced after a node's hostname, and used by other nodes in order to peer and connect with each other. These files are constantly created and destroyed by their respective nodes, so that the data remains fresh and accurate.

If tor is enabled for a given node, its share data can also be copied to other machines for more complex configurations.

## Development

*Work in progress. Feel free to hack the project on your own!*

There are three main modes to choose from when launching a container: **safe mode**, **development mode**, and **headless mode**.

By default, a node will launch in safe mode. A copy of the `/run` folder is made at build time, and code changes to `/run` will not affect the node (unless you rebuild and re-launch). The node will continue to run in the background once you exit the node terminal. The node is also configured to self-restart in the event of a crash.

When launching a node with `--devmode` enabled, a few things change. The `node-start` script will not start automatically; you will have to call it yourself. The `/run` folder will be mounted directly into the container, so you can modify the source code in real-time.

Any changes to the source code will apply to *all* nodes. Re-run the start script to apply changes. When you exit the terminal, the container will be instantly destroyed, however the internal `/data` store will persist.

If you end up borking a node, use the `--wipe` flag at launch to erase the node's persistent storage. The start scripts are designed to be robust, and nodes are highly disposable. Feel free to crash, wipe, and re-launch nodes as often as you like!

Both safe-mode and dev-mode can be augmented with `--headless` mode, which launches a node without connecting to it. You can still monitor nodes through a management service like **portainer**, or simply login to the node using `./workbench login *nametag*`.

To mount folders into a node's environment, use the format `--mount local/path:/mount/path`. Paths can be relative or absolute.

To open and forward ports from a node's environment, use the format `--ports int1:ext1,int2:ext2, ...`, with a comma to separate port declarations, and colon to separate internal:external ports.

The `--passthru` flag will allow you to pass a quoted string of flags directly to the internal `docker run` script. With great power comes great responsibility! :-)

## Contribution

All suggestions and contributions are welcome! If you have any questions about this project, feel free to submit an issue up above, or contact me on social media.

## Tools

**LNURL Decoder**  
https://lnurl.fiatjaf.com/codec

## Resources

**Bitcoin Developer Reference**  
A great resource for documentation on Bitcoin's RPC interface, and other technical details.  
https://developer.bitcoin.org/reference/index.html

**Bitcoin Github Docs**  
Another great resource for all things related to Bitcoin Core.  
https://github.com/bitcoin/bitcoin/tree/master/doc

**Core Lightning Documentation**  
The go-to resource for Core Lightning's RPC interface.  
https://lightning.readthedocs.io

**Core Lighting REST API Docs**  
Documentation for the REST interface that is provided by the RTL team.  
https://github.com/Ride-The-Lightning/c-lightning-REST#apis

**Bolt 12 Landing Page**  
A nice landing page for info regarding the Bolt 12 specification.  
https://bolt12.org

**Sparko Client**  
Incredibly useful web-rpc interface and web-client for Core Lightning.  
https://github.com/fiatjaf/sparko-client

**Pyln-client**  
The main library for interfacing with Core Lightning over RPC. Very powerful.  
https://github.com/ElementsProject/lightning/tree/master/contrib/pyln-client

**Python Documentation**  
Official resource for the python language.  
https://docs.python.org/3

**Flask Documentation**  
The go-to resource for documentation on using Flask.  
https://flask.palletsprojects.com/en/2.1.x

**Node.js Documentation**  
The go-to resource for documentation on using Nodejs.  
https://nodejs.org/api
