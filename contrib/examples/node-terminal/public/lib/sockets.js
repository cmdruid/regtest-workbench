import EventEmitter from './events.js'

/* For preparing data before sending it over the wire. */
const encode = data => JSON.stringify(data)
const decode = data => JSON.parse(data.toString('utf8'))

let wss;

export default function getSocket(url) {
  if (!wss) {
    /* Setup new websocket client and emitter. */
    wss = new WebSocket(url);
    wss.emitter = new EventEmitter();

    /* Initialize heartbeat on socket open. */
    wss.addEventListener('open', heartbeat);

    /* Interface our websocket to the event emitter. */
    wss.addEventListener('message', event => {
      if (event.data === 'ping') return heartbeat(event)
      const { type, data } = decode(event.data)
      try {
        /* You can add your own message types! */
        switch(type) {
          case 'msg':
            console.log('Message from server:', data)
            break
          case 'event':
            wss.emitter.emit('event', data)
            break
          default:
            wss.emitter.emit(type, data)
        }
      } catch(err) { console.error(err) }
    });
    
    /* Forward call events to the server. */
    wss.emitter.on('call', e => {
      wss.send(encode({ type: 'call', data: e }))
    });

    /* Close our connection if heartbeat dies. */
    wss.addEventListener('close', function clear() {
      console.log('Closing connection with server.')
      clearTimeout(this.pingTimeout);
    });
  }
  return wss
}

function heartbeat(event) {
  /* Our heart beats ping, pong. */
  const { currentTarget: ws } = event;
  clearTimeout(ws.pingTimeout);
  ws.pingTimeout = setTimeout(() => { 
    ws.close();
  }, 30000 + 1000);
}
