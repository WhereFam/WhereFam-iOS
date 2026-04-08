// app/js/hyperbee-manager.js
// WhereFam — all structured on-device data in one Hyperbee
//
// Key namespaces:
//   identity/      — mnemonic, publicKey
//   peers/<key>    — trusted peer metadata
//   profile/       — local user name + avatar
//   places/<id>    — geofence places

const Hyperbee  = require('hyperbee')
const Hypercore = require('hypercore')

let db = null

async function initializeHyperbee (documentsPath) {
  if (db) return db
  const core = new Hypercore(documentsPath + '/db', { valueEncoding: 'json', compat: false })
  db = new Hyperbee(core, { keyEncoding: 'utf-8', valueEncoding: 'json' })
  await db.ready()
  console.log('[hyperbee] ready')
  return db
}

function getDB () {
  if (!db) throw new Error('[hyperbee] not initialized')
  return db
}

// Profile

async function saveProfile (profile) {
  const store = getDB()
  if (profile.name        !== undefined) await store.put('profile/name',   profile.name)
  if (profile.avatarBase64 !== undefined) await store.put('profile/avatar', profile.avatarBase64)
}

async function getProfile () {
  const store = getDB()
  const [name, avatar] = await Promise.all([store.get('profile/name'), store.get('profile/avatar')])
  return { name: name?.value ?? null, avatarBase64: avatar?.value ?? null }
}

// Peers

async function savePeer (publicKeyBase64, meta = {}) {
  const store    = getDB()
  const existing = await store.get(`peers/${publicKeyBase64}`)
  await store.put(`peers/${publicKeyBase64}`, {
    addedAt: existing?.value?.addedAt ?? new Date().toISOString(),
    name:    meta.name ?? existing?.value?.name ?? null
  })
}

async function removePeer (publicKeyBase64) {
  await getDB().del(`peers/${publicKeyBase64}`)
}

async function getKnownPeers () {
  const peers = new Map()
  for await (const { key, value } of getDB().createReadStream({ gt: 'peers/', lt: 'peers/~' })) {
    peers.set(key.slice('peers/'.length), value)
  }
  return peers
}

async function isPeerKnown (publicKeyBase64) {
  return (await getDB().get(`peers/${publicKeyBase64}`)) !== null
}

// Places

async function savePlace (place) {
  await getDB().put(`places/${place.id}`, place)
}

async function deletePlace (id) {
  await getDB().del(`places/${id}`)
}

async function getAllPlaces () {
  const places = []
  for await (const { value } of getDB().createReadStream({ gt: 'places/', lt: 'places/~' })) {
    places.push(value)
  }
  return places
}

module.exports = {
  initializeHyperbee, getDB,
  saveProfile, getProfile,
  savePeer, removePeer, getKnownPeers, isPeerKnown,
  savePlace, deletePlace, getAllPlaces
}