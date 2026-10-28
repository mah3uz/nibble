import { router } from '@inertiajs/vue3'
import { nextTick, onScopeDispose, watch } from 'vue'
import { addHistoryGuard } from './history-guard'

const BASE = 'nibbleDialogBase'
const ENTRY = 'nibbleDialog'

type State = Record<string, unknown> | null
type Entry = { token: string; href: string; page: unknown }

const open: Array<() => void> = []
let entry: Entry | null = null
let leaving: { token?: string; page?: unknown } | null = null
let visits = 0
let scheduled = false
let installed = false

const here = () => window.location.href.split('#')[0]
const state = () => window.history.state as State

function withoutMarks(value: State) {
  const copy = { ...value }
  delete copy[BASE]
  delete copy[ENTRY]
  return copy
}

// The entry beneath ours missed any page Inertia wrote into ours while a dialog was open, so it takes that page over.
function restore(page: unknown) {
  window.history.replaceState({ ...withoutMarks(state()), page }, '')
}

function sync() {
  if (visits > 0 || leaving) return
  const current = state()
  if (open.length && !entry) {
    if (!current?.page) return
    const token = `${Date.now().toString(36)}${Math.random().toString(36).slice(2)}`
    window.history.replaceState({ ...withoutMarks(current), [BASE]: token }, '')
    window.history.pushState({ ...withoutMarks(current), [ENTRY]: token }, '')
    entry = { token, href: here(), page: current.page }
  } else if (!open.length && entry) {
    leaving = { token: entry.token, page: current?.page }
    entry = null
    window.history.back()
  }
}

function schedule() {
  if (scheduled) return
  scheduled = true
  nextTick(() => {
    scheduled = false
    sync()
  })
}

function onPopstate(event: PopStateEvent) {
  const popped = event.state as State
  if (leaving) {
    const left = leaving
    leaving = null
    schedule()
    if (left.token === undefined) return true
    if (popped?.[BASE] !== left.token) return false
    restore(left.page)
    return true
  }
  if (entry) {
    const left = entry
    entry = null
    if (popped?.[BASE] !== left.token) return false
    restore(left.page)
    open.at(-1)?.()
    schedule()
    return true
  }
  if (popped?.[ENTRY]) {
    leaving = {}
    window.history.back()
    return true
  }
  return false
}

function install() {
  if (installed) return
  installed = true
  addHistoryGuard(onPopstate)
  // A visit made while a dialog's entry is current lands on that entry, so leaving the page leaves no dead entry behind.
  router.on('before', (event) => {
    if (entry && !event.detail.visit.prefetch) event.detail.visit.replace = true
  })
  router.on('start', (event) => {
    if (!event.detail.visit.prefetch) visits++
  })
  router.on('finish', (event) => {
    if (event.detail.visit.prefetch) return
    visits = Math.max(0, visits - 1)
    if (entry && here() !== entry.href) entry = null
    else if (entry) {
      entry.page = state()?.page
      window.history.replaceState({ ...withoutMarks(state()), [ENTRY]: entry.token }, '')
    }
    schedule()
  })
  router.on('navigate', schedule)
}

export function useDialogHistory(isOpen: () => boolean | undefined, close: () => void) {
  if (typeof window === 'undefined') return
  install()
  const request = () => close()
  const remove = () => {
    const index = open.indexOf(request)
    if (index < 0) return
    open.splice(index, 1)
    schedule()
  }
  watch(
    () => !!isOpen(),
    (value) => {
      if (!value) return remove()
      if (open.includes(request)) return
      open.push(request)
      schedule()
    },
    { immediate: true },
  )
  onScopeDispose(remove)
}
