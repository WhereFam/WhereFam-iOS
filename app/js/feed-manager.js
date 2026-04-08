// app/js/feed-manager.js
const Corestore = require('corestore')
const b4a       = require('b4a')
const ipc       = require('./ipc')

let store   = null
let ownFeed = null

const peerFeeds = new Map()

async function initFeeds (documentsPath, keyPair) {
  store = new Corestore(documentsPath + '/feeds')
  await store.ready()

  // keyPair = { publicKey: Buffer, secretKey: Buffer } from hypercore-crypto
  ownFeed = store.get({ keyPair, valueEncoding: 'json' })
  await ownFeed.ready()

  console.log('[feeds] own feed ready, length:', ownFeed.length)
  return store
}

function getStore () { return store }

function replicateStore (mux) {
  if (!store) throw new Error('[feeds] not initialized')
  store.replicate(mux)
}

async function openPeerFeed (peerKeyBuffer, peerBase64) {
  if (peerFeeds.has(peerBase64)) return peerFeeds.get(peerBase64)

  const feed = store.get({ key: peerKeyBuffer, valueEncoding: 'json' })
  await feed.ready()
  peerFeeds.set(peerBase64, feed)

  const stream = feed.createReadStream({ live: true, start: Math.max(0, feed.length - 1) })
  stream.on('data', (entry) => {
    if (entry?.latitude && entry?.longitude) {
      ipc.send('locationUpdate', { ...entry, _fromFeed: true })
    }
  })
  stream.on('error', (err) => {
    if (err.code === 'REQUEST_CANCELLED') return  // normal on disconnect
    console.error('[feeds] stream error:', err.message)
  })

  console.log('[feeds] opened peer feed:', peerBase64.slice(0, 8), 'length:', feed.length)
  return feed
}

function closePeerFeed (peerBase64) {
  const feed = peerFeeds.get(peerBase64)
  if (feed) { feed.close().catch(() => {}); peerFeeds.delete(peerBase64) }
}

async function appendLocation (entry) {
  if (!ownFeed) throw new Error('[feeds] not initialized')
  await ownFeed.append(entry)
}

async function readPeerHistory (peerBase64, limit = 200) {
  const feed = peerFeeds.get(peerBase64)
  if (!feed || feed.length === 0) return []
  const start = Math.max(0, feed.length - limit)
  const entries = []
  for (let i = start; i < feed.length; i++) {
    try { const e = await feed.get(i); if (e) entries.push(e) } catch {}
  }
  return entries
}

module.exports = { initFeeds, getStore, replicateStore, openPeerFeed, closePeerFeed, appendLocation, readPeerHistory }
