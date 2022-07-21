#!/usr/bin/env bash

printf "Test script initiated!\n"

PSBT=`lightning-cli splice_init $PEER_ID | jq -r .psbt`
PSBT_FUNDS=`lightning-cli fundpsbt 100000sat slow 166 | jq -r .psbt`
PSBT=`bitcoin-cli joinpsbts "[\"$PSBT\", \"$PSBT_FUNDS\"]"`
PSBT=`lightning-cli splice_update $PEER_ID $PSBT | jq -r .psbt`
PSBT=`lightning-cli splice_finalize $PEER_ID | jq -r .psbt`
PSBT=`lightning-cli signpsbt -k psbt="$PSBT" | jq -r .signed_psbt`
# l1-cli splice_signed $PEER_ID $PSBT
TX=`lightning-cli splice_signed $PEER_ID $PSBT | jq -r .tx`
bitcoin-cli sendrawtransaction $TX

printf "Splice complete!\n"