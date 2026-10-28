import { afterEach, beforeEach, describe, expect, test, vi } from 'vitest'
import { effectScope, nextTick, ref } from 'vue'

type Handler = (event: { detail: { visit: Record<string, unknown> } }) => void
const handlers = vi.hoisted(() => new Map<string, Handler>())
vi.mock('@inertiajs/vue3', () => ({
  router: {
    on: (name: string, handler: Handler) => {
      handlers.set(name, handler)
      return () => handlers.delete(name)
    },
  },
}))

type State = Record<string, unknown> | null

// A session history that traverses asynchronously, as browsers do, and reports which popstates reach Inertia.
function browser() {
  const entries: { state: State; url: string }[] = [
    { state: { page: 'previous' }, url: 'https://cms.test/cp' },
    { state: { page: 'media' }, url: 'https://cms.test/cp/media' },
  ]
  let index = 1
  const listeners: ((event: PopStateEvent) => void)[] = []
  const inertiaSaw: State[] = []
  const traverse = (delta: number) =>
    setTimeout(() => {
      index += delta
      let stopped = false
      const event = {
        state: structuredClone(entries[index].state),
        stopImmediatePropagation: () => (stopped = true),
      } as unknown as PopStateEvent
      for (const listener of listeners) {
        if (stopped) break
        listener(event)
      }
      if (!stopped) inertiaSaw.push(event.state)
    })
  const history = {
    get state() {
      return structuredClone(entries[index].state)
    },
    pushState(state: State, _title: string, url?: string) {
      entries.splice(index + 1)
      entries.push({ state: structuredClone(state), url: url ?? entries[index].url })
      index++
    },
    replaceState(state: State, _title: string, url?: string) {
      entries[index] = { state: structuredClone(state), url: url ?? entries[index].url }
    },
    back: () => traverse(-1),
    forward: () => traverse(1),
  }
  vi.stubGlobal('window', {
    history,
    location: {
      get href() {
        return entries[index].url
      },
    },
    addEventListener: (_type: string, listener: (event: PopStateEvent) => void) => listeners.push(listener),
  })
  return { entries, history, inertiaSaw, index: () => index }
}

const settle = async () => {
  for (let i = 0; i < 3; i++) {
    await new Promise((resolve) => setTimeout(resolve))
    await nextTick()
  }
}

let useDialogHistory: typeof import('../dialog-history').useDialogHistory
let site: ReturnType<typeof browser>

function dialog({ dismissable = true } = {}) {
  const open = ref(false)
  const scope = effectScope()
  scope.run(() =>
    useDialogHistory(
      () => open.value,
      () => {
        if (dismissable) open.value = false
      },
    ),
  )
  return { open, unmount: () => scope.stop() }
}

function visit(url: string, page: string) {
  const pending: Record<string, unknown> = { replace: false, prefetch: false }
  handlers.get('before')!({ detail: { visit: pending } })
  handlers.get('start')!({ detail: { visit: pending } })
  const same = url === window.location.href
  if (pending.replace || same) site.history.replaceState({ page }, '', url)
  else site.history.pushState({ page }, '', url)
  return () => handlers.get('finish')!({ detail: { visit: pending } })
}

beforeEach(async () => {
  handlers.clear()
  vi.resetModules()
  site = browser()
  ;(await import('../history-guard')).installHistoryGuard()
  useDialogHistory = (await import('../dialog-history')).useDialogHistory
})

afterEach(() => {
  vi.unstubAllGlobals()
})

describe('useDialogHistory', () => {
  test('Back closes the open dialog and stays on the page, without Inertia seeing it', async () => {
    const editor = dialog()
    editor.open.value = true
    await settle()
    expect(site.entries).toHaveLength(3)

    site.history.back()
    await settle()

    expect(editor.open.value).toBe(false)
    expect(site.index()).toBe(1)
    expect(site.inertiaSaw).toEqual([])
  })

  test('closing the dialog itself removes its entry, so the next Back leaves the page', async () => {
    const editor = dialog()
    editor.open.value = true
    await settle()

    editor.open.value = false
    await settle()
    expect(site.index()).toBe(1)
    expect(site.inertiaSaw).toEqual([])

    site.history.back()
    await settle()
    expect(site.index()).toBe(0)
    expect(site.inertiaSaw).toEqual([{ page: 'previous' }])
  })

  test('nested dialogs close one per Back, innermost first', async () => {
    const outer = dialog()
    const inner = dialog()
    outer.open.value = true
    await settle()
    inner.open.value = true
    await settle()

    site.history.back()
    await settle()
    expect([outer.open.value, inner.open.value]).toEqual([true, false])

    site.history.back()
    await settle()
    expect([outer.open.value, inner.open.value]).toEqual([false, false])
    expect(site.index()).toBe(1)
    expect(site.inertiaSaw).toEqual([])
  })

  test('a visit to another page from an open dialog takes over its entry, and closing it does not undo the visit', async () => {
    const editor = dialog()
    editor.open.value = true
    await settle()

    const finish = visit('https://cms.test/cp/entries/1', 'entry')
    editor.unmount()
    finish()
    await settle()

    expect(site.entries.map((entry) => entry.url)).toEqual([
      'https://cms.test/cp',
      'https://cms.test/cp/media',
      'https://cms.test/cp/entries/1',
    ])
    expect(site.index()).toBe(2)
  })

  test('a save that returns to the same page leaves that newer page in history once the dialog closes', async () => {
    const editor = dialog()
    editor.open.value = true
    await settle()

    const finish = visit('https://cms.test/cp/media', 'media saved')
    finish()
    editor.open.value = false
    await settle()

    expect(site.index()).toBe(1)
    expect(site.history.state).toMatchObject({ page: 'media saved' })
  })

  test('Back after a same-page reload in an open dialog keeps the reloaded page in history', async () => {
    const editor = dialog()
    editor.open.value = true
    await settle()
    visit('https://cms.test/cp/media', 'media reloaded')()
    await settle()

    site.history.back()
    await settle()

    expect(editor.open.value).toBe(false)
    expect(site.index()).toBe(1)
    expect(site.history.state).toMatchObject({ page: 'media reloaded' })
  })

  test('Forward after a Back-close neither reopens the dialog nor reaches Inertia', async () => {
    const editor = dialog()
    editor.open.value = true
    await settle()
    site.history.back()
    await settle()

    site.history.forward()
    await settle()

    expect(editor.open.value).toBe(false)
    expect(site.index()).toBe(1)
    expect(site.inertiaSaw).toEqual([])
  })

  test('a dialog that refuses to close keeps an entry, so Back still stays on the page', async () => {
    const warning = dialog({ dismissable: false })
    warning.open.value = true
    await settle()

    site.history.back()
    await settle()

    expect(warning.open.value).toBe(true)
    expect(site.index()).toBe(2)
    expect(site.inertiaSaw).toEqual([])
  })
})
