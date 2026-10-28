import { router } from '@inertiajs/vue3'
import { nextTick, onScopeDispose, watch } from 'vue'
import { addHistoryGuard } from './history-guard'

const BASE = 'nibbleDialogBase'
const ENTRY = 'nibbleDialog'

type State = Record<string, unknown> | null

const open: Array<() => void> = []
let entry: { token: string; href: string } | null = null
let leaving: { token?: string } | null = null
let visits = 0
const navigations = new Set<string>()
let writes = 0
let rewrite = false
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

function sync() {
  if (visits > 0 || leaving) return
  const current = state()
  if (open.length && !entry) {
    if (!current?.page) return
    const token = `${Date.now().toString(36)}${Math.random().toString(36).slice(2)}`
    window.history.replaceState({ ...withoutMarks(current), [BASE]: token }, '')
    window.history.pushState({ ...withoutMarks(current), [ENTRY]: token }, '')
    entry = { token, href: here() }
    rewrite = false
  } else if (!open.length && entry) {
    leaving = { token: entry.token }
    entry = null
    window.history.back()
  } else if (!open.length && rewrite) {
    // Inertia may have written a newer page into the dialog's entry; this writes its current page into the entry now
    // current, through its own history queue so the write lands after any of its own still pending.
    rewrite = false
    router.remember(++writes, ENTRY)
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
    rewrite = true
    return true
  }
  if (entry) {
    const left = entry
    entry = null
    if (popped?.[BASE] !== left.token) return false
    rewrite = true
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
  // A visit that would push while a dialog's entry is current replaces that entry instead, so leaving the page leaves
  // no dead entry behind.
  router.on('before', ({ detail: { visit } }) => {
    if (!entry || visit.prefetch || visit.replace) return
    visit.replace = true
    navigations.add(visit.id)
  })
  router.on('start', (event) => {
    if (!event.detail.visit.prefetch) visits++
  })
  router.on('finish', (event) => {
    if (event.detail.visit.prefetch) return
    visits = Math.max(0, visits - 1)
    const navigated = navigations.delete(event.detail.visit.id)
    if (entry && navigated && here() !== entry.href) entry = null
    else if (entry) {
      entry.href = here()
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
