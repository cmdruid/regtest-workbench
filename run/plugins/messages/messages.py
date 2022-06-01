#!/usr/bin/env python3
## Reference implementation of a basic plugin.
## Uses methods, hooks, subscriptions and custom notifications.

from pyln.client import Plugin
import random

plugin = Plugin()


# @plugin.method('sendmessage')
# def send_msg(plugin, peer_id, payload):
#   """Messages are in the byte format of [type(2)][id(8)][data]."""
#   msgtype = int(plugin.mtype, 16)
#   msgid   = random.randint(0, 2**64)
#   msg     = (msgtype.to_bytes(2, 'big')
#             + msgid.to_bytes(8, 'big')
#             + bytes(payload, encoding='utf8'))
#   res = plugin.rpc.call('sendcustommsg', {'node_id': peer_id, 'msg': msg.hex()})
#   return res


# @plugin.async_hook('custommsg')
# def on_custommsg(peer_id, payload, plugin, **kwargs):
#   """Use custommsg hook to receive payload."""
#   pbytes  = bytes.fromhex(payload)
#   mtype   = int.from_bytes(pbytes[:2], "big")
#   plugin.log('Received payload type: {}'.format(hex(mtype)))
#   if hex(mtype) === plugin.mtype.lower():
#     msgid   = int.from_bytes(pbytes[2:10], "big")
#     data    = pbytes[10:].decode()
#     message = dict({ 'peer': peer_id, 'msgid': msgid, 'data': data })
#     plugin.notify("message", message)

#   return {'result': 'continue'}


# @plugin.subscribe('message')
# def on_newmessage(plugin, origin, payload, **kwargs):
#   """Custom notifications include an origin and payload argument."""
#   plugin.log("Received message: {}".format(payload))
#   return payload


@plugin.init()
def init(options, configuration, plugin):
  #plugin.mtype = plugin.get_option('mtype')
  plugin.log("Plugin messages.py initialized.")
  return


plugin.add_notification_topic('message')
plugin.add_option('mtype', '0xFFFF', 'Set the message type, in hex. Must be odd number. Default 0xFFFF')

plugin.run() ## test 1 2 3 4sadasdasdasdasd