// app/js/app.js
/* global Bare, BareKit */
'use strict'

const EventEmitter      = require('bare-events')
const ipc               = require('./ipc')
const hyperbeeManager   = require('./hyperbee-manager')
const identityManager   = require('./identity-manager')
const feedManager       = require('./feed-manager')
const hyperswarmManager = require('./hyperswarm-manager')
const protocolManager   = require('./protocol-manager')
const pairingManager    = require('./pairing-manager')

const app = new EventEmitter()

app.on('start', async ({ path }) => {
  try {
    console.log('[app] booting...')

    const bee = await hyperbeeManager.initializeHyperbee(path)
    await identityManager.initIdentity(bee)

    const keyPair      = identityManager.getKeyPair()
    const publicKeyHex = identityManager.getPublicKeyHex()

    await feedManager.initFeeds(path, keyPair)
    const swarm = await hyperswarmManager.initializeHyperswarm(keyPair)
    protocolManager.setupProtocol()
    pairingManager.init(swarm)

    // Re-join known peers from previous sessions
    const knownPeers = await hyperbeeManager.getKnownPeers()
    for (const [peerHex] of knownPeers) {
      await hyperswarmManager.joinPeer(peerHex)
    }

    ipc.send('ready', { publicKey: publicKeyHex })
    console.log('[app] ready, pk:', publicKeyHex.slice(0, 12) + '...')

  } catch (err) {
    console.error('[app] startup failed:', err)
    ipc.send('startupError', { message: err.message })
  }
})

ipc.on('start',    (data) => app.emit('start', data))
ipc.on('joinPeer', (id)   => hyperswarmManager.joinPeer(id))
ipc.on('leavePeer',(id)   => hyperswarmManager.leavePeer(id))

ipc.on('requestPublicKey', () => {
  ipc.send('publicKeyResponse', { publicKey: identityManager.getPublicKeyHex() })
})

// Blind pairing — User A creates invite
ipc.on('createInvite', async () => {
  try {
    const inviteHex = await pairingManager.createInvite(identityManager.getPublicKeyHex())
    ipc.send('inviteCreated', { invite: inviteHex })
  } catch (e) {
    console.error('[pairing] createInvite error:', e.message)
  }
})

// Blind pairing — User B joins with scanned invite
ipc.on('joinWithInvite', async ({ invite }) => {
  try {
    await pairingManager.joinWithInvite(invite, identityManager.getPublicKeyHex())
  } catch (e) {
    console.error('[pairing] joinWithInvite error:', e.message)
  }
})

ipc.on('locationUpdate',          (data) => protocolManager.sendLocation(data))
ipc.on('backgroundLocationBurst', (data) => protocolManager.sendLocation(data))
ipc.on('placeEvent',              (data) => protocolManager.sendPlaceEvent(data))
ipc.on('sosAlert',                (data) => protocolManager.sendSOS(data))
ipc.on('batteryUpdate',           (data) => protocolManager.sendBattery(data))

ipc.on('requestHistory', async ({ peerKey }) => {
  await protocolManager.sendHistoryToSwift(peerKey)
})
