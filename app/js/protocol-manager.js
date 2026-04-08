// app/js/protocol-manager.js
const c                 = require('compact-encoding')
const hyperswarmManager = require('./hyperswarm-manager')
const feedManager       = require('./feed-manager')
const ipc               = require('./ipc')

const PROTOCOL = 'wherefam/v1'
const channels = new Map()  // hex → { locationMsg, placeMsg, sosMsg, batteryMsg }

function setupProtocol () {
  console.log('[protocol] registering protocol handler')
  hyperswarmManager.registerProtocol(PROTOCOL, (mux, peerHex) => {
    console.log('[protocol] setting up channel for:', peerHex.slice(0, 12))
    const channel = mux.createChannel({
      protocol: PROTOCOL,
      onopen  () { console.log('[protocol] open:', peerHex.slice(0, 12)) },
      onclose () {
        channels.delete(peerHex)
        console.log('[protocol] closed:', peerHex.slice(0, 12))
      }
    })

    const locationMsg = channel.addMessage({
      encoding: c.json,
      onmessage (msg) {
        console.log('[protocol] received location from:', peerHex.slice(0, 12))
        if (!msg.timestamp) msg.timestamp = Date.now()
        ipc.send('locationUpdate', msg)
      }
    })

    const placeMsg   = channel.addMessage({
      encoding: c.json,
      onmessage (msg) { ipc.send('placeEvent', msg) }
    })
    const sosMsg     = channel.addMessage({
      encoding: c.json,
      onmessage (msg) { ipc.send('sosAlert', msg) }
    })
    const batteryMsg = channel.addMessage({
      encoding: c.json,
      onmessage (msg) { ipc.send('batteryUpdate', msg) }
    })

    channels.set(peerHex, { locationMsg, placeMsg, sosMsg, batteryMsg })
    channel.open()
  })
}

async function sendLocation (data) {
  const entry = {
    id:              data.id,
    name:            data.name,
    latitude:        data.latitude,
    longitude:       data.longitude,
    altitude:        data.altitude        ?? null,
    speed:           data.speed           ?? null,
    batteryLevel:    data.batteryLevel    ?? null,
    batteryCharging: data.batteryCharging ?? null,
    timestamp:       data.timestamp       || Date.now(),
    ...(data.avatarData ? { avatarData: data.avatarData } : {})
  }

  try { await feedManager.appendLocation(entry) } catch (e) {
    console.error('[protocol] feed append error:', e.message)
  }

  const count = channels.size
  broadcast('locationMsg', entry)
}

function sendPlaceEvent (data) { broadcast('placeMsg',   data) }
function sendSOS         (data) { broadcast('sosMsg',     data) }
function sendBattery     (data) { broadcast('batteryMsg', data) }

async function sendHistoryToSwift (peerHex) {
  const entries = await feedManager.readPeerHistory(peerHex)
  if (entries.length > 0) ipc.send('historyUpdate', { peerKey: peerHex, entries })
}

function broadcast (msgKey, payload) {
  for (const [key, ch] of channels) {
    try {
      ch[msgKey].send(payload)
    } catch (e) {
      console.error('[protocol] send error to', key.slice(0, 12), e.message)
    }
  }
}

module.exports = { setupProtocol, sendLocation, sendPlaceEvent, sendSOS, sendBattery, sendHistoryToSwift }
