import { reactive } from 'vue'

const IDLE_MS = 15 * 60 * 1000
const WARN_SECONDS = 60
const ACTIVITY = ['pointerdown', 'keydown', 'wheel', 'touchstart'] as const
const SHARED_KEY = 'nibble:last-activity'

export const elevation = reactive({
  locked: false,
  warning: false,
  dismissed: false,
  remaining: IDLE_MS / 1000,
  elevatedUntil: null as number | null,
})

let lastActivity = Date.now()
let lastShared = 0

export const elevated = () => elevation.elevatedUntil !== null && elevation.elevatedUntil > Date.now()

function readShared() {
  try {
    return Number(localStorage.getItem(SHARED_KEY)) || 0
  } catch {
    return 0
  }
}

// Other tabs see this, so working in one tab keeps the rest from locking.
function share(at: number) {
  if (at - lastShared < 5000) return
  lastShared = at
  try {
    localStorage.setItem(SHARED_KEY, String(at))
  } catch {
    // Private windows can refuse storage; the tab still times out on its own.
  }
}

function touch() {
  lastActivity = Date.now()
  share(lastActivity)
}

export function noteActivity() {
  if (typeof window === 'undefined' || elevation.locked || elevation.warning) return
  touch()
}

function tick() {
  if (elevation.locked) return
  const idleSince = Math.max(lastActivity, readShared())
  elevation.remaining = Math.max(0, Math.ceil((idleSince + IDLE_MS - Date.now()) / 1000))
  if (elevation.remaining === 0) {
    elevation.locked = true
    elevation.warning = false
    elevation.dismissed = false
  } else if (elevation.remaining <= WARN_SECONDS) {
    elevation.warning = true
  } else {
    elevation.warning = false
    elevation.dismissed = false
  }
}

export function extendSession() {
  elevation.warning = false
  elevation.dismissed = false
  lastShared = 0
  touch()
  tick()
}

// Called from onMounted: the admin shell is server-rendered, where there is no window to listen on.
export function watchIdle() {
  if (typeof window === 'undefined') return () => {}

  touch()
  const timer = setInterval(tick, 1000)
  const onVisible = () => document.visibilityState === 'visible' && tick()
  ACTIVITY.forEach((name) => window.addEventListener(name, noteActivity, { passive: true }))
  document.addEventListener('visibilitychange', onVisible)
  return () => {
    clearInterval(timer)
    ACTIVITY.forEach((name) => window.removeEventListener(name, noteActivity))
    document.removeEventListener('visibilitychange', onVisible)
  }
}

export function elevationGranted(until: number) {
  elevation.elevatedUntil = until
  elevation.locked = false
  extendSession()
}

export async function elevate(password: string) {
  const csrf = document.querySelector<HTMLMetaElement>('meta[name=csrf-token]')?.content ?? ''
  const response = await fetch('/cp/session/elevate', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', Accept: 'application/json', 'X-CSRF-Token': csrf },
    body: JSON.stringify({ password }),
  })
  if (response.ok) {
    elevationGranted(Date.now() + IDLE_MS)
    return null
  }
  const body = await response.json().catch(() => ({}))
  return (body.error as string) ?? 'That password was refused.'
}
