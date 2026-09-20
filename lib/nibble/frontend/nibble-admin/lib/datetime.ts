// The site's configured timezone (Rails config.time_zone, an IANA name) can differ from the
// viewer's browser timezone, so every conversion goes through Intl with an explicit `timeZone` —
// never the browser's local time (which `new Date(...).toISOString()` would use).
function offsetAt(instant: Date, timezone: string): string {
  const parts = new Intl.DateTimeFormat('en-US', { timeZone: timezone, timeZoneName: 'longOffset' }).formatToParts(
    instant,
  )
  const name = parts.find((p) => p.type === 'timeZoneName')?.value ?? 'GMT+00:00'
  return name.replace('GMT', '') || '+00:00'
}

// A wall-clock time near a DST transition is ambiguous about which offset applies until you
// already know the offset, so this converges on one: guess, look up what that guess's offset
// would be, and repeat until the guess stops moving (real IANA zones settle in 1-2 iterations).
function offsetFor(isoLocal: string, timezone: string): string {
  let instant = new Date(`${isoLocal}Z`)
  for (let i = 0; i < 3; i++) {
    const offset = offsetAt(instant, timezone)
    const candidate = new Date(`${isoLocal}${offset}`)
    if (candidate.getTime() === instant.getTime()) return offset
    instant = candidate
  }
  return offsetAt(instant, timezone)
}

export function toIsoWithOffset(dateIso: string, time: string, timezone: string): string {
  const isoLocal = `${dateIso}T${time || '00:00'}:00`
  return `${isoLocal}${offsetFor(isoLocal, timezone)}`
}

export function fromIso(iso: string | null, timezone: string): { dateIso: string | null; time: string } {
  if (!iso) return { dateIso: null, time: '' }

  const parts = new Intl.DateTimeFormat('en-CA', {
    timeZone: timezone,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
    hour12: false,
  }).formatToParts(new Date(iso))
  const get = (type: string) => parts.find((p) => p.type === type)?.value ?? '00'
  return { dateIso: `${get('year')}-${get('month')}-${get('day')}`, time: `${get('hour')}:${get('minute')}` }
}
