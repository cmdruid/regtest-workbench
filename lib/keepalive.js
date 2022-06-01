export default function keepAlive(wss) {

  const interval = setInterval(function ping() {
    /* Check to make sure our connections aren't dead. */
    wss.clients.forEach(function each(ws) {
      if (ws.isAlive === false) return ws.terminate();
      ws.isAlive = false;
      ws.ping()
      /* Browser websockets cannot react to ping events,
         so we have to explicitly send a ping message. */
      ws.send('ping')
    });
  }, 30000);

  wss.on('connection', function connection(ws) {
    /* Setup a heartbeat monitor on first connect. */
    ws.isAlive = true;
    ws.on('pong', function heartbeat() {
      /* Still alive! */
      this.isAlive = true;
    });
  });

  wss.on('close', function close() {
    /* Clean up a few things on connection close. */
    clearInterval(interval);
  });
}
