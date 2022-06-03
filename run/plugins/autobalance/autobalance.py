#!/usr/bin/env python3
from pyln.client import Plugin
import random

plugin = Plugin()

## Unique header bytes for our messages.
MESSAGE_TYPE = '0xF1FB'
THRESHOLD = 2


@plugin.subscribe("channel_opened")
def on_channel_opened(plugin, channel_opened, **kwargs):
  """Capture channel open event and add collect info about peer."""
  event  = channel_opened
  peerId = event['id']
  if peerId not in plugin.pending:
    amt = int(event['amount'].replace('msat', ''))
    plugin.pending[peerId] = int(amt // 2)
  plugin.log("Added peer to channel pending list: {}".format(peerId))


@plugin.subscribe("channel_state_changed")
def on_channel_state_changed(plugin, channel_state_changed, **kwargs):
  """Capture state change event, and send peer an invoice."""
  event    = channel_state_changed
  peerId   = event['peer_id']
  isNormal = (event['new_state'] == 'CHANNELD_NORMAL')
  if peerId in plugin.pending:
    amount  = plugin.pending.pop(peerId)
    invoice = generate_invoice(amount, peerId)
    send_invoice(peerId, invoice)
    

def generate_invoice(amount, peer, label='autopay'):
  """Generate an invoice for peer."""
  rand_id = str(random.randint(0, 2**64))
  invoice = plugin.rpc.call('invoice', [ amount, rand_id, label ])
  plugin.log(f"Generated {label} invoice for {amount} msats.")
  return invoice['bolt11']


# @plugin.method("autobalance")
# def auto_balance(peer_id):
#   peer    = plugin.rpc.call('listpeers', [peer_id])['peers'][0]
#   channel = peer['channels'][0]
#   spend   = int(channel['spendable_msatoshi'])
#   recv    = int(channel['receivable_msatoshi'])
#   if not spend:
#     return
#   elif not recv:
#     amount = spend // 2


@plugin.method("autoinvoice")
def send_invoice(peer_id, bolt11):
  """Send an invoice to peer."""
  msgtype = int(MESSAGE_TYPE, 16)
  msgid   = random.randint(0, 2**64)
  msg     = (msgtype.to_bytes(2, 'big')
            + msgid.to_bytes(8, 'big')
            + bytes(bolt11, encoding='utf8'))
  plugin.log("Sending invoice to peer: {}".format(peer_id))
  plugin.rpc.call('sendcustommsg', {'node_id': peer_id, 'msg': msg.hex()})
  return "Sent invoice to peer: {}".format(peer_id)


def pay_invoice(bolt11):
  """Pay a BOLT11 invoice."""
  result = plugin.rpc.call('pay', [ bolt11 ])
  plugin.log(f"Paid auto-balance invoice for {result['msatoshi']} msats.")


@plugin.async_hook('custommsg')
def on_custommsg(peer_id, payload, plugin, request, **kwargs):
  """Use custommsg hook to receive invoice requests."""
  pbytes  = bytes.fromhex(payload)
  mtype   = int.from_bytes(pbytes[:2], "big")
  ## Check if message header matches our type.
  if hex(mtype) == MESSAGE_TYPE.lower():
    msgid   = int.from_bytes(pbytes[2:10], "big")
    data    = pbytes[10:].decode()
    plugin.log('Received invoice request from peer: {}'.format(peer_id))
    pay_invoice(data)
    return
  return request.set_result({'result': 'continue'})


@plugin.init()
def init(options, configuration, plugin, **kwargs):
  """Initialize our plugin."""
  plugin.pending = dict()
  plugin.log("Plugin autobalance.py initialized!")


plugin.run()