#!/usr/bin/env python3
## Reference implementation of a basic plugin.
## Uses methods, hooks, subscriptions and custom notifications.

from pyln.client import Plugin
from operator    import itemgetter
import json, random

plugin = Plugin()


@plugin.method('sendmessage')
def send_msg(plugin, peer_id, payload):
  """Messages are in the byte format of [type(2)][id(8)][data]."""
  msgtype = int(plugin.mtype, 16)
  msgid   = random.randint(0, 2**64)
  msg     = (msgtype.to_bytes(2, 'big')
            + msgid.to_bytes(8, 'big')
            + bytes(payload, encoding='utf8'))
  res = plugin.rpc.call('sendcustommsg', {'node_id': peer_id, 'msg': msg.hex()})
  return res


@plugin.async_hook('custommsg')
def on_custommsg(peer_id, payload, plugin, request, **kwargs):
  """Use custommsg hook to receive payload."""
  pbytes  = bytes.fromhex(payload)
  mtype   = hex(int.from_bytes(pbytes[:2], "big"))
  plugin.log('Noticed payload type: {}'.format(mtype))
  if mtype == plugin.mtype.lower():
    msgid   = int.from_bytes(pbytes[2:10], "big")
    data    = pbytes[10:].decode()
    message = dict({ 'peer': peer_id, 'msgid': hex(msgid), 'data': data })
    plugin.notify("messagebus", json.dumps(message))
  return request.set_result({'result': 'continue'})


@plugin.subscribe('messagebus')
def on_newmessage(plugin, origin, payload, request, **kwargs):
  """Custom notifications include an origin and payload argument."""
  d = json.loads(payload)
  peer, msgid, data = d['peer'], d['msgid'], d['data']
  plugin.log(f"Received message {msgid} from {peer}: {data}")
  return


@plugin.init()
def init(options, configuration, plugin):
  plugin.mtype = plugin.get_option('mtype')
  plugin.log("Plugin messages.py initialized.")
  return


plugin.add_notification_topic('messagebus')
plugin.add_option('mtype', '0xFFFF', 'Set the message type, in hex. Must be odd number. Default 0xFFFF')

plugin.run()