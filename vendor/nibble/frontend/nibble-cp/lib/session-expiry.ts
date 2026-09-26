import { reactive } from 'vue'
import { postJson } from './elevation'

export const WARN_AT = 60
// Longer than a tick means the tab slept, so the local count can't be trusted.
const STALE_MS = 10_000

export const expiry = reactive({
  lifetime: 0,
  count: 0,
  remaining: 0,
  signedOut: false,
  twoFactor: false,
  dismissedWarning: false,
  dismissedSignIn: false,
})

let pinging = false
let lastTick = Date.now()

export const warning = () => !expiry.signedOut && expiry.count <= WARN_AT

export function start(lifetime: number, remaining: number | null) {
  expiry.lifetime = lifetime
  expiry.count = expiry.remaining = remaining ?? lifetime
  expiry.signedOut = false
}

// The server counts every request as activity, so a page visit restarts the clock here too.
export function active() {
  if (expiry.signedOut) return
  expiry.count = expiry.remaining = expiry.lifetime
  expiry.dismissedWarning = false
}

export async function ping() {
  if (pinging || document.hidden) return
  pinging = true
  try {
    const response = await fetch('/cp/session/timeout', { headers: { Accept: 'application/json' } })
    if (response.status === 401) {
      expiry.count = expiry.remaining = 0
    } else if (response.ok) {
      const { remaining } = await response.json()
      expiry.count = expiry.remaining = remaining
    }
    expiry.signedOut = expiry.remaining <= 0 && !expiry.twoFactor
  } catch {
    // Offline for a moment: the next tick asks again.
  } finally {
    pinging = false
  }
}

function tick() {
  if (expiry.signedOut || expiry.twoFactor) return
  expiry.count = Math.max(0, expiry.count - 1)
  const stale = Date.now() - lastTick > STALE_MS
  lastTick = Date.now()
  if (expiry.count <= WARN_AT || stale) void ping()
}

export function watchExpiry() {
  if (typeof window === 'undefined') return () => {}
  lastTick = Date.now()
  const timer = window.setInterval(tick, 1000)
  const onVisible = () => !document.hidden && void ping()
  document.addEventListener('visibilitychange', onVisible)
  return () => {
    window.clearInterval(timer)
    document.removeEventListener('visibilitychange', onVisible)
  }
}

export async function extend() {
  const response = await postJson('/cp/session/extend')
  if (response.status === 401) {
    expiry.count = expiry.remaining = 0
    expiry.signedOut = true
    return
  }
  if (response.ok) active()
}

type Answer = { error?: string; two_factor?: boolean }

async function answer(response: Response): Promise<Answer> {
  const body = (await response.json().catch(() => ({}))) as Answer
  if (!response.ok) return { error: body.error ?? 'Something went wrong. Try again.' }
  return body
}

function signedIn() {
  expiry.signedOut = false
  expiry.twoFactor = false
  expiry.dismissedSignIn = false
  active()
}

export async function signIn(email: string, password: string) {
  const result = await answer(await postJson('/cp/session', { email_address: email, password }))
  if (result.error) return result.error
  if (result.two_factor) {
    expiry.twoFactor = true
    return null
  }
  signedIn()
  return null
}

export async function confirmCode(code: string) {
  const result = await answer(await postJson('/cp/session/challenge', { code }))
  if (result.error) return result.error
  signedIn()
  return null
}
