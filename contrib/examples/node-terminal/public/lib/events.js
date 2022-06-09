/** events.js
 * Basic implementation of an event emitter class.
 * */

class EventEmitter {

  constructor() {
    this.events = {};
  }

  _getEventListByName(eventName) {
    /** If key undefined, create a new set for the event, 
     * else return the stored subscriber list.
     */
    if (typeof this.events[eventName] === 'undefined') {
      this.events[eventName] = new Set();
    }
    return this.events[eventName];
  }

  on(eventName, fn) {
    /** Subscribe function to run on a given event. */
    this._getEventListByName(eventName).add(fn);
  }

  once(eventName, fn) {
    /** Subscribe function to run once, using
     * a callback to cancel the subscription.
     */
    const self = this;

    const onceFn = function(...args) {
      self.removeListener(eventName, onceFn);
      fn.apply(self, args);
    };

    this.on(eventName, onceFn);
  }

  emit(eventName, ...args) {
    /** Emit a series of arguments for the event, and
     * present them to each subscriber in the list.
     */
    this._getEventListByName(eventName).forEach(function(fn) {
      fn.apply(this, args);
    }.bind(this));
  }
  
  removeListener(eventName, fn) {
    /** Remove function from an event's subscribtion list. */
    this._getEventListByName(eventName).delete(fn);
  }
}

export default EventEmitter;