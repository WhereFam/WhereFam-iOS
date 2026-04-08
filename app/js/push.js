// app/js/push.js
// WhereFam — Notification Service Extension worklet

BareKit.on('push', (rawPayload, reply) => {
  let p = {}
  try { p = JSON.parse(rawPayload) } catch {}

  const name = p.name || 'Someone'
  let title  = 'WhereFam'
  let body   = `${name} shared an update`

  switch (p.event) {
    case 'arrived':
      title = `${p.emoji ?? '📍'} ${name} arrived`
      body  = `at ${p.placeName ?? 'a saved place'}`
      break
    case 'left':
      title = `${p.emoji ?? '📍'} ${name} left`
      body  = p.placeName ?? 'a saved place'
      break
    case 'sos':
      title = `🆘 ${name} sent an SOS`
      body  = 'Tap to see their location'
      break
    case 'crash':
      title = `🚨 ${name} may have been in a crash`
      body  = 'Tap to see their location'
      break
    case 'lowBattery':
      title = `🔋 ${name}'s battery is low`
      body  = p.batteryLevel != null ? `${Math.round(p.batteryLevel * 100)}% remaining` : 'Charge soon'
      break
    default:
      body = `${name} shared their location`
  }

  reply(null, JSON.stringify({ title, body }))
})