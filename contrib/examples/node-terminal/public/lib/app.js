import getSocket from "./sockets.js"

/* Fetch our configured socket. */
const socket = getSocket('wss://127.0.0.1:8999')

const events = [];     // Store our event messages in here.
const MAX_EVENTS = 25  // We'll prune messages after this amount.

const infoWindow  = document.querySelector('.info-window pre')
const termWindow  = document.querySelector('.terminal-window')
const eventWindow = document.querySelector('.event-window')
const termInput   = document.querySelector('.terminal-prompt input')
const sendButton  = document.querySelector('.send-btn')

socket.addEventListener('open', () => {
  /* When the socket connects, fetch info from our node. */
  socket.emitter.emit('call', ['getinfo'])
});

socket.emitter.on('getinfo', data => {
  /* Unpack our big fat data object. */
  const { 
    id, alias, num_peers, num_active_channels, 
    version, blockheight, network, msatoshi_fees_collected
  } = data

  /* Do something cool, like change our username to the node alias. */
  const username = document.querySelector('.prompt-user')
  username.textContent = `root@${alias.toLowerCase()}`

  /* Change the window contents to our formatted string. */
  infoWindow.textContent = `id:${id}
peers: ${num_peers} | network: ${network} | blockheight: ${blockheight}
channels: ${num_active_channels} | fees: ${msatoshi_fees_collected} | version: ${version}`
});

socket.emitter.on('event', ({ event, data }) => {
  /* Listen for event messages and post them to our log window. */
  const logEntry = document.createElement("pre")
  if (eventWindow.children.length > MAX_EVENTS) {
    eventWindow.lastElementChild.remove()
  }
  logEntry.classList.add("log-entry")
  logEntry.textContent = format(data)
  eventWindow.prepend(logEntry)
});


termInput.addEventListener('keypress', e => {
  /* Capture 'enter' keypress from the command line. */
  if (e.key === 'Enter') sendCommand(e.target.value) 
});

sendButton.addEventListener('click', e => {
  /* Capture mouse-clicks on our enter button. */
  sendCommand(termInput.value)
})

function sendCommand(str) {
  /* Parse our command string and send it over the wire. */
  const [ command, ...args ] = str.split(' ')
  socket.emitter.on(command, data => {
    /* Setup our callback for the command response. */
    const termEntry = document.createElement("pre")
    termEntry.classList.add("term-entry")
    termEntry.textContent = format(data)
    termWindow.replaceChildren()
    termWindow.append(termEntry)
    termWindow.scrollTo({ top: 0 })
  });
  /* Send the command and reset our command line. */
  socket.emitter.emit('call', [ command, ... args ])
  termInput.value=""
}

function format(json) {
  /* Convert ugly json objects into pretty text. */
  const text = JSON.stringify(json, null, 1)
  if (text.startsWith('{')) text = text.slice(2, -2)
  return text
}

