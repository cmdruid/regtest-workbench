import express from 'express';
import sparko  from 'sparko-client';
import { readFileSync }    from 'fs';
import { createServer }    from 'https';
import { WebSocketServer } from 'ws';

import keepAlive from './lib/keepalive';

const events = [
  'channel_opened',
  'connect',
  'disconnect',
  'invoice_payment',
  'invoice_creation',
  'warning',
  'forward_event',
  'sendpay_success',
  'sendpay_failure',
  'coin_movement'
]

/* Initialize our sparko client. */
const sparkClient = sparko(process.env.SPARK_HOST, process.env.SPARK_KEY)

/* Setup our express app. */
const app = express();
app.use(express.static('public'));

/* Setup our HTTPS server. */
const server = createServer({
  cert: readFileSync('crt.pem'),
  key: readFileSync('key.pem')
}, app);

/* Setup our Websocket server. */
const wss = new WebSocketServer({ server });
const encode = data => JSON.stringify(data)
const decode = data => JSON.parse(data.toString('utf8'))

/* Enable our heartbeat monitor. */
keepAlive(wss)

wss.on('connection', (ws) => {
  /* Broadcast event listeners to our websocket clients. */
  for (let event of events) {
    sparkClient[event] = data => {
      wss.clients.forEach(client => {
        let payload = { event: event, data: data },
            encoded = encode({ type: 'event', data: payload })
        if (client.isAlive) client.send(encoded);
      });
    }
  }
  
  ws.on('message', async payload => {
    /* Handle incoming message types from our clients. */
    const { type, data } = decode(payload)
    console.log('Received message type:', type)
    try {
      /* Switch for handling various message types. */
      switch(type) {
        case 'call':
          return callHandler(ws, data)
        default:
          return ws.send(encode({ type: 'msg', data: data}))
      }
    } catch(err) { console.error(err) }
  });

  /* Send a feedback message when a client connects. */   
  ws.send(encode({type: 'msg', data: 'Connected!'}));
});

async function callHandler(ws, data) {
  /* Handle calling the sparko plugin. */
  const [ method, ...args ] = data
  if (!method) return
  return sparkClient.call(method, [ ...args ])
    .then(res => ws.send(encode({ type: method, data: res })))
    .catch(err => console.error(err))
}

/* Configure and start our webserver. */
const port = process.env.PORT || 8999,
      addr = process.env.hostname || "127.0.0.1"

server.listen(port, addr, () => {
  console.info(`Server started on: ${addr}:${port}`)
  console.info('Node Environment:', process.env.NODE_ENV || 'PRODUCTION')
});
