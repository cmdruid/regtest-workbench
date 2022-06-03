#!/usr/bin/env python3
from pyln.client import Plugin
from time        import sleep
from threading   import Timer
from random      import randrange

plugin = Plugin()


def get_dict(key, val, dicts):
  return next((d for d in dicts if d[key] == val ), None)


@plugin.method("paytraffick")
def paytraffick(plugin, command, *args, **kwargs):
  """Sets up automated payment traffic between nodes and channels."""
  if command == 'addpeer' and args[0]:
    plugin.plist.add(args[0])
    return 'Added peer to list.'
  if command == 'delpeer' and args[0]:
    plugin.plist.discard(args[0])
    return 'Removed peer from list.'
  if command == 'start':
    plugin.status = 'enabled'
    plugin.args = args or 'interval'  ##plugin.get_option('pt-mode')
    kwargs.update(plugin.options)
    traffick_daemon(plugin)
  if command == 'stop':
    plugin.status = 'disabled'
  return f"Paytraffick currently '{plugin.status}' with arguments {plugin.args}."


def traffick_daemon(plugin):
  ## Manages the event loop for the plugin.
  if plugin.status == 'enabled':
    interval = plugin.options['interval']
    traffick_loop(plugin)
    Timer(interval, traffick_daemon, args=[plugin]).start()
  return


def traffick_loop(plugin):
  ## Main plugin logic for automatically scanning channels and sending invoices.
  ## Also poll plugin queue for new messages.

  args, options, plist = plugin.args, plugin.options, plugin.plist
  base_amt, interval,  = options['amount'], options['interval']

  try:
    peers = get_peer_info()

    if not plist or 'all' in args:
      plist = [ peer['id'] for peer in peers ]

    if 'random' in args:
      selection = randrange(0, len(plist))
      peer = get_dict('id', plist[selection], peers)
      send_balanced_invoice(peer, base_amt)

    elif 'interval' in args:
      for peer_id in iter(plist):
        peer = get_dict('id', peer_id, peers)
        send_balanced_invoice(peer, base_amt)
        sleep(2)
  
  except Exception as err:
    plugin.log(f'Error: {json.dumps(err, indent=2)}')


def get_peer_info():
  """Get detailed information on current peers."""
  peers = []
  for peer in plugin.rpc.call('listpeers')['peers']:
    has_channel = (peer['channels'] and peer['channels'][0]['state'] == "CHANNELD_NORMAL")
    if peer['connected'] and has_channel:
      spend = int(peer['channels'][0]['spendable_msatoshi'])
      recv  = int(peer['channels'][0]['receivable_msatoshi'])
      peers.append({'id': peer['id'], 'spend': spend, 'recv': recv})
  return peers


def send_balanced_invoice(peer, base_amt):
  alias = plugin.rpc.call('getinfo')['alias']
  peer_id, spend, recv = peer['id'], peer['spend'], peer['recv']
  amount = get_skewed_amount(spend, recv, base_amt)
  if not amount:
    plugin.log(f'Peer {peer_id} is broke! Skipping ...')
    return
  plugin.rpc.call('autoinvoice', [ peer_id, amount, f'From {alias}'])
  plugin.log(f'Sending invoice for {amount} msat to peer: {peer_id}')



def get_skewed_amount(spend, recv, base):
  if not recv or recv < (spend * 0.5):
    return int(randrange(base, base * 2))
  if not spend:
    return 0
  return int(randrange(base * 0.5, base * 2))


@plugin.init()
def init(options, configuration, plugin, **kwargs):
  plugin.plist   = set()
  plugin.args    = tuple()
  plugin.status  = plugin.get_option('pt-status')
  plugin.options = {
    "amount": int(plugin.get_option('pt-amount')),
    "interval": int(plugin.get_option('pt-interval'))
  }
  plugin.log("Paytraffick initialized")


plugin.add_option('pt-status', 'disabled', "Default status which paytraffick starts with.")
plugin.add_option('pt-amount', '1000000', "Default amount for generating invoices, in msats.")
plugin.add_option('pt-mode', 'interval', "Default mode which paytraffick starts with.")
plugin.add_option('pt-interval', '10', "Default interval which invoices are dispatched, in seconds.")

plugin.run()

## test