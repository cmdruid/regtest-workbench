# bash_aliases
## This file is loaded upon login to your node terminal, 
## and can be used to customize your environment. Feel free to 
## modify this file, like adding your own aliases and shortcuts!

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
alias qrbtconion='cat /data/tor/services/btc/hostname | qrencode -m 2 -t "ANSIUTF8"'
alias qrclnonion='cat /data/tor/services/cln/hostname | qrencode -m 2 -t "ANSIUTF8"'

## Generates a sparko QR code for connecting to zeus via Tor.
## Must have tor enabled so that a hostname is generated!
alias qrsparko='\
  HOST="$(cat /data/tor/services/cln/hostname)" \
  && CRED="$(cat /data/lightning/sparko.keys | kgrep MASTER_KEY)" \
  && printf "http://$HOST:9737?access-key=$CRED" | qrencode -m 2 -t "ANSIUTF8"'