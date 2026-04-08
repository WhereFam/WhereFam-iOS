// app/js/identity-manager.js
const crypto = require('hypercore-crypto')
const b4a    = require('b4a')

let _keyPair = null

async function initIdentity (bee) {
  const stored = await bee.get('identity/secretKey')

  if (stored && typeof stored.value === 'string' && stored.value.length === 128) {
    const secretKey = b4a.from(stored.value, 'hex')
    const publicKey = b4a.from(stored.value.slice(64), 'hex')
    _keyPair = { publicKey, secretKey }
    console.log('[identity] loaded, pk:', getPublicKeyHex().slice(0, 12))
  } else {
    _keyPair = crypto.keyPair()
    // Store secretKey as hex string (Hyperbee uses json encoding)
    await bee.put('identity/secretKey', b4a.toString(_keyPair.secretKey, 'hex'))
    console.log('[identity] new, pk:', getPublicKeyHex().slice(0, 12))
  }

  return _keyPair
}

function getKeyPair ()      { return _keyPair }
function getPublicKeyHex () { return _keyPair ? b4a.toString(_keyPair.publicKey, 'hex') : null }

module.exports = { initIdentity, getKeyPair, getPublicKeyHex }
