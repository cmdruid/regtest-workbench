#!/usr/bin/env python3
## Reference implementation of a basic plugin.
## Uses methods, hooks, subscriptions and custom notifications.

from pyln.client import Plugin

import random, sys

plugin = Plugin()

@plugin.method('sendmessage')
def send_msg(plugin, peer_id, payload):
  """Messages are in the byte format of [type(2)][id(8)][data]."""
  msgtype = int(plugin.get_option('mtype'), 16)
  msgid   = random.randint(0, 2**64)
  msg     = (msgtype.to_bytes(2, 'big')
            + msgid.to_bytes(8, 'big')
            + bytes(payload, encoding='utf8'))
  res = plugin.rpc.call('sendcustommsg', {'node_id': peer_id, 'msg': msg.hex()})
  return "Message sent: {}".format(res)


@plugin.async_hook('custommsg')
def on_custommsg(peer_id, payload, plugin, **kwargs):
  """Use custommsg hook to receive payload."""
  pbytes  = bytes.fromhex(payload)
  mtype   = int.from_bytes(pbytes[:2], "big")
  msgid   = int.from_bytes(pbytes[2:10], "big")
  data    = pbytes[10:].decode()
  payload = dict({ 'peer': peer_id, 'mtype': mtype, 'msgid': msgid, 'data': data })

  plugin.notify("newmessage", payload)

  return {'result': 'continue'}


@plugin.subscribe('newmessage')
def on_newmessage(plugin, origin, payload, **kwargs):
  """Custom notifications include an origin and payload argument."""
  response = "Received new message from {}: {}".format(origin, payload)
  plugin.log(response)
  sys.stdout.write(response)


@plugin.init()
def init(options, configuration, plugin):
  """This can also return {'disabled': <reason>} to self-disable."""
  plugin.log("Plugin messages initialized.")
  return


plugin.add_notification_topic('newmessage')
plugin.add_option('mtype', '0xFFFF', 'Set the message type, in hex. Default 0xFFFF')

plugin.run()