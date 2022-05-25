# Plugins
Here is a list of decorators and methods that you can use to build custom plugins. For more information, check out the source code for [plugin.py](https://github.com/ElementsProject/lightning/blob/master/contrib/pyln-client/pyln/client/plugin.py).

## Decorator Methods
These are decorators used to wrap a function.
```py
@plugin.init()
"""Decorator to call a function after plugin initialization."""

@plugin.method(method_name)
"""Decorator to add a plugin method to the dispatch table."""

@plugin.async_method(method_name)
"""Decorator to add an async plugin method to the dispatch table."""

@plugin.hook(hook_name)
"""Decorator to add a plugin hook to the dispatch table."""

@plugin.async_hook(hook_name)
"""Decorator to add an async plugin hook to the dispatch table."""

@plugin.subscribe(topic)
"""Function decorator to register a notification handler."""
```

## Setter Methods
These are methods used to register additional information about your plugin. They can be placed after your decorated methods, but before you call `Plugin.run()`.
```py
plugin.add_option(option_name, default_value, description, option_type)
"""Add an option that we'd like to register with lightningd. 
"""

plugin.add_notification_topic(topic_name)
"""Announce that the plugin will emit notifications for the topic.
"""
```

## Functional Methods
These are methods that you will use within your plugin's application logic.
```py
plugin.get_option(option_name)
"""Get the user-provided (or default) value of an option."""

plugin.log(log_message)
"""Log a message to the lightningd log file."""

plugin.print_usage()
"""Prints a datailed help / usage text to stdout."""

plugin.notify(topic_name, params_json)
"""Send a notification to subscribers."""

plugin.notify_message(request_object, message)
"""Send a notification message to sender of this request"""

plugin.notify_progress(request_object, progress_int, total_int, stage_int, stage_total_int)
"""Send a progress message to sender of this request: if more than one stage, set stage and stage_total"""
```

# Resources

**Core Lightning Plugin Documentation**  
https://lightning.readthedocs.io/PLUGINS.html

**Python Client Library for Core Lightning**  
https://github.com/ElementsProject/lightning/tree/master/contrib/pyln-client

**Repository of Core Lightning Plugins**  
https://github.com/lightningd/plugins



