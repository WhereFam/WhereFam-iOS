// app/js/ipc.js
// WhereFam — raw IPC transport between Swift and Bare

const { IPC } = BareKit
const EventEmitter = require('bare-events')

const emitter = new EventEmitter()
let buffer = ''

IPC.setEncoding('utf8')

IPC.on('data', (chunk) => {
  buffer += chunk
  let idx
  while ((idx = buffer.indexOf('\n')) !== -1) {
    const line = buffer.slice(0, idx).trim()
    buffer = buffer.slice(idx + 1)
    if (!line) continue
    try {
      const msg = JSON.parse(line)
      if (msg?.action) emitter.emit(msg.action, msg.data)
    } catch (e) {
      console.error('[ipc] parse error:', e.message)
    }
  }
})

function send (action, data) {
  IPC.write(JSON.stringify({ action, data }) + '\n')
}

module.exports = {
  on:  (action, fn) => emitter.on(action, fn),
  off: (action, fn) => emitter.off(action, fn),
  send
}