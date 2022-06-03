#!/usr/bin/env python3
## Monitor plugins for hotloading.

from pyln.client import Plugin, RpcError
from subprocess  import check_output
from shlex       import split
from os          import scandir
from os.path     import dirname
from hashlib     import md5
from time        import sleep
from glob        import glob
from threading   import Timer

import json

DEFAULT_PLUGPATH = dirname(dirname(__file__))
DEFAULT_INTERVAL = 5

plugin = Plugin()
watch_list = dict()


@plugin.method('hotload')
def hotload(plugin, command=None, **kwargs):
  """Controls the start and stop of the monitor daemon."""
  if command == 'start':
    plugin.runstate = 'enabled'
    plugin_monitor(plugin)
  if command == 'stop':
    plugin.runstate = 'disabled'
  return f"Hotload status: '{plugin.runstate}'. Use commands 'start' or 'stop' to change it."
    

def plugin_monitor(plugin):
  """Simple implementation of a threaded callback loop."""
  if plugin.runstate == 'enabled':
    check_plugins(plugin.watchpath)
    Timer(plugin.interval, plugin_monitor, args=[plugin]).start()
  return


def check_plugins(watchpath):
  """Main logic for diff checking each plugin folder."""
  fields = 'mode uid gid size mtime ctime'
  with scandir(watchpath) as entries:
    for entry in entries:

      if entry.name.startswith('.') or entry.is_file():
        continue
      if not (fpath := glob(f'{entry.path}/{entry.name}.*')):
        continue

      pname = entry.name
      stats = check_output(split(f'ls -l {entry.path}')).decode('ascii')
      mhash = md5(stats.encode('utf-8')).hexdigest()

      if not pname in watch_list:
        print(f"Registering {pname} with hash: {mhash}")
        watch_list[pname] = mhash
      elif watch_list[pname] != mhash:
        print(f"Changes in '{pname}' plugin detected! Reloading ...")
        restart_plugin(pname, fpath[0])
        watch_list[pname] = mhash
      else:
        continue
  return watch_list


def restart_plugin(pname, fpath):
  """Attempt to start/restart the plugin using LightningRpc."""
  try:
    plugin.rpc.call('plugin', { 'subcommand': 'start', 'plugin': fpath })
  except RpcError as err:
    print(f"Plugin '{pname}' failed to execute: {err.error}")


@plugin.init()
def init(options, configuration, plugin):
  """Initialize plugin object."""
  plugin.runstate  = plugin.get_option('hotload-state')
  plugin.watchpath = plugin.get_option('hotload-path')
  plugin.interval  = int(plugin.get_option('hotload-interval'))
  plugin.log(f"Hotloader initialized!")
  plugin.log("Watch path set to: {}".format(plugin.watchpath))
  return


plugin.add_option('hotload-state', 'disabled', f"Default state of plugin when lightningd starts.")
plugin.add_option('hotload-path', DEFAULT_PLUGPATH, f"Plugin path to check for file changes. Default is {DEFAULT_PLUGPATH} path.")
plugin.add_option('hotload-interval', DEFAULT_INTERVAL, f"Interval to check for file changes. Default is {DEFAULT_INTERVAL} seconds.")

plugin.run()