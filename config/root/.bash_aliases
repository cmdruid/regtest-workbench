# bash_aliases
## This file is loaded upon login to your node terminal, 
## and can be used to customize your environment. Feel free to 
## modify this file, like adding your own aliases and shortcuts!

## Alias index.
alias aliases='printf "Available Aliases:
  Command-line
    bcli        Shortcut to bitcoin-cli interface.
    lcli        Shortcut to lightning-cli interface.

  Networking
    opensock    List sockets that are open and listening.

  Logging
    bdlog       Tail the bitcoind daemon log.
    ldlog       Tail the lightningd daemon log.
    torlog      Tail the tor daemon log.
    minelog     Tail the miner script log.
  
  QR Codes
    qrbtchost   Generate a QR code for the bitcoin onion hostname.
    qrclnhost   Generate a QR code for the lightning onion hostname.
    qrsparko    Generate a QR code for using sparko connect.
\n"'

## Short-hand for bitcoin / lightning CLI.
alias bcli='bitcoin-cli'
alias lcli='lightning-cli'

## Useful for checking open sockets.
alias opensockets='lsof -nP -iTCP -sTCP:LISTEN'
alias listsockets='ss -tunlp'

## Shortcuts to logfiles.
alias bdlog='tail -f /var/log/bitcoin/debug.log'
alias ldlog='tail -f /var/log/lightning/lightningd.log'
alias torlog='tail -f /var/log/tor/notice.log'
alias minelog='tail -f /var/log/regminer.log'

## Get QR codes for onion strings.
alias qrbtchost='cat /data/tor/services/btc/hostname | qrencode -m 2 -t "ANSIUTF8"'
alias qrclnhost='cat /data/tor/services/cln/hostname | qrencode -m 2 -t "ANSIUTF8"'

## Generates a sparko QR code for connecting to zeus via Tor.
## Must have tor enabled so that a hostname is generated!
alias qrsparko='\
  HOST="$(cat /data/tor/services/cln/hostname)" \
  && CRED="$(cat /data/lightning/sparko.keys | kgrep MASTER_KEY)" \
  && printf "http://$HOST:9737?access-key=$CRED" | qrencode -m 2 -t "ANSIUTF8"'