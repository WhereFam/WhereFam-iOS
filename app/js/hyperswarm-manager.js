// app/js/hyperswarm-manager.js
const Hyperswarm      = require('hyperswarm')
const Protomux        = require('protomux')
const crypto          = require('hypercore-crypto')
const b4a             = require('b4a')
const ipc             = require('./ipc')
const hyperbeeManager = require('./hyperbee-manager')
const feedManager     = require('./feed-manager')

let swarm    = null
let _ownKey  = null  // our public key hex

const connections      = new Map()  // hex → { mux, conn }
const protocolHandlers = new Map()  // name → handler fn
const leaveSet         = new Set()  // explicitly-left peers (hex)
const joinedTopics     = new Map()  // peerHex → discovery instance

async function initializeHyperswarm (keyPair) {
  if (swarm) return swarm

  _ownKey = b4a.toString(keyPair.publicKey, 'hex')

  swarm = new Hyperswarm({
    keyPair,
    firewall (remotePublicKey) {
      return leaveSet.has(b4a.toString(remotePublicKey, 'hex'))
    }
  })

  swarm.on('connection', handleConnection)
  console.log('[hyperswarm] ready')
  return swarm
}

// Derive a shared topic from two peer keys — same result on both sides
// since we sort before hashing
function peerTopic (ownHex, peerHex) {
  const keys = [ownHex, peerHex].sort()
  return crypto.hash(b4a.from(keys[0] + keys[1]))
}

function handleConnection (conn, info) {
  const key    = b4a.toString(info.publicKey, 'hex')
  const keyBuf = info.publicKey

  if (leaveSet.has(key)) { conn.destroy(); return }

  console.log('[hyperswarm] connected:', key.slice(0, 12))

  const mux = new Protomux(conn)
  connections.set(key, { mux, conn })

  feedManager.replicateStore(mux)
  feedManager.openPeerFeed(keyBuf, key).catch(console.error)

  for (const handler of protocolHandlers.values()) handler(mux, key)

  // Persist every successful connection for reconnection on reboot
  hyperbeeManager.savePeer(key).catch(console.error)

  conn.on('close', () => {
    connections.delete(key)
    feedManager.closePeerFeed(key)
    ipc.send('peerDisconnected', { peerKey: key })
    console.log('[hyperswarm] disconnected:', key.slice(0, 12))
  })
  conn.on('error', (err) => console.error('[hyperswarm] conn error:', key.slice(0, 12), err.message))
}

async function joinPeer (peerHex) {
  if (!swarm) { console.error('[hyperswarm] not initialized'); return }
  if (joinedTopics.has(peerHex)) return  // already joining

  console.log('[hyperswarm] joining peer:', peerHex.slice(0, 12))
  leaveSet.delete(peerHex)
  await hyperbeeManager.savePeer(peerHex)

  // Use topic-based join so both sides find each other regardless of who opens first
  // This keeps announcing on DHT and retries until connected
  const topic = peerTopic(_ownKey, peerHex)
  const discovery = swarm.join(topic)
  joinedTopics.set(peerHex, discovery)
  await discovery.flushed()
  console.log('[hyperswarm] announced on topic for:', peerHex.slice(0, 12))
}

async function leavePeer (peerHex) {
  if (!swarm) return
  leaveSet.add(peerHex)

  // Stop announcing on topic
  const discovery = joinedTopics.get(peerHex)
  if (discovery) { await discovery.destroy(); joinedTopics.delete(peerHex) }

  const entry = connections.get(peerHex)
  if (entry) { entry.conn.destroy(); connections.delete(peerHex) }

  feedManager.closePeerFeed(peerHex)
  await hyperbeeManager.removePeer(peerHex)
}

function registerProtocol (name, handler) { protocolHandlers.set(name, handler) }
function getSwarm () { if (!swarm) throw new Error('[hyperswarm] not initialized'); return swarm }

module.exports = { initializeHyperswarm, joinPeer, leavePeer, registerProtocol, getSwarm, connections }
