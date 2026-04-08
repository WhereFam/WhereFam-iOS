// app/js/pairing-manager.js
// blind-pairing usage for WhereFam:
//
// autobaseKey = random 32 bytes (just a rendezvous secret, not an actual autobase)
// userData    = our publicKey (so the other side knows who we are)
// result.key  = the autobaseKey (we ignore this)
// candidate.userData = peer's publicKey (what we actually want)

const BlindPairing    = require('blind-pairing')
const crypto          = require('hypercore-crypto')
const b4a             = require('b4a')
const ipc             = require('./ipc')
const hyperswarmManager = require('./hyperswarm-manager')
const hyperbeeManager   = require('./hyperbee-manager')

let _pairing = null

function init (swarm) {
  _pairing = new BlindPairing(swarm)
  console.log('[pairing] ready')
}

// User A — generate invite, wait for candidate
async function createInvite (ownPublicKeyHex) {
  if (!_pairing) throw new Error('[pairing] not initialized')

  // Random rendezvous secret — just needed to derive the DHT discovery key
  const rendezvousKey = crypto.randomBytes(32)
  const { invite, publicKey, discoveryKey } = BlindPairing.createInvite(rendezvousKey)

  const member = _pairing.addMember({
    discoveryKey,
    async onadd (candidate) {
      console.log('[pairing] candidate arrived')
      candidate.open(publicKey)

      // candidate.userData is the peer's public key (hex buffer)
      const peerKeyHex = b4a.toString(candidate.userData, 'hex')
      console.log('[pairing] peer key:', peerKeyHex.slice(0, 12))

      // Confirm — key doesn't matter, peer gets it via onadd result
      candidate.confirm({ key: rendezvousKey })

      // Connect and save
      await hyperswarmManager.joinPeer(peerKeyHex)
      await hyperbeeManager.savePeer(peerKeyHex)
      ipc.send('peerPaired', { peerKey: peerKeyHex })
    }
  })

  await member.flushed()

  const inviteHex = b4a.toString(invite, 'hex')
  console.log('[pairing] invite ready:', inviteHex.slice(0, 12))
  return inviteHex
}

// User B — join using invite from User A
async function joinWithInvite (inviteHex, ownPublicKeyHex) {
  if (!_pairing) throw new Error('[pairing] not initialized')

  const invite   = b4a.from(inviteHex, 'hex')
  const userData = b4a.from(ownPublicKeyHex, 'hex')  // send our public key

  const candidate = _pairing.addCandidate({
    invite,
    userData,
    async onadd (result) {
      // result.key = rendezvousKey (ignore it)
      // We need User A's public key — but User A didn't send it as userData.
      // Instead, User A will joinPeer(us) and we'll get connected via Hyperswarm.
      // The connection event fires and we handle it normally in hyperswarm-manager.
      console.log('[pairing] pairing confirmed by host')
      ipc.send('peerPaired', { peerKey: ownPublicKeyHex })
    }
  })

  await candidate.pairing
  console.log('[pairing] paired:', candidate.paired)
}

module.exports = { init, createInvite, joinWithInvite }
