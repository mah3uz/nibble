import { createSSRApp } from 'vue'
import { renderToString } from 'vue/server-renderer'
import { afterEach, describe, expect, it, vi } from 'vitest'
import ThemeSwitch from '../components/ThemeSwitch.vue'

// Runs the mounted hook at once, so the server renderer draws what a browser shows once JavaScript has loaded.
vi.mock('vue', async (original) => ({
  ...(await original<typeof import('vue')>()),
  onMounted: (fn: () => void) => fn(),
}))

function browser({ theme, saved, prefersDark = false }: { theme?: string; saved?: string; prefersDark?: boolean }) {
  const storage = new Map(saved ? [['crumbs-theme', saved]] : [])
  const document = { cookie: '', documentElement: { dataset: theme ? { theme } : ({} as Record<string, string>) } }
  vi.stubGlobal('document', document)
  vi.stubGlobal('localStorage', {
    getItem: (key: string) => storage.get(key) ?? null,
    removeItem: (key: string) => storage.delete(key),
  })
  vi.stubGlobal('window', { matchMedia: () => ({ matches: prefersDark }) })
  return { document, storage }
}

const render = () => renderToString(createSSRApp(ThemeSwitch))

afterEach(() => vi.unstubAllGlobals())

describe('crumbs ThemeSwitch', () => {
  it('follows the choice the shell wrote from the cookie, over the system setting', async () => {
    browser({ theme: 'light', prefersDark: true })
    expect(await render()).toContain('aria-checked="true"')
  })

  it('follows the system setting when the visitor has not chosen', async () => {
    browser({ prefersDark: true })
    expect(await render()).toContain('aria-checked="false"')
  })

  it('moves a choice saved by an earlier version into the cookie, so it reaches the first paint from then on', async () => {
    const { document, storage } = browser({ saved: 'dark' })

    expect(await render()).toContain('aria-checked="false"')
    expect(document.cookie).toBe('nibble_theme=dark; path=/; max-age=31536000; samesite=lax')
    expect(document.documentElement.dataset.theme).toBe('dark')
    expect(storage.has('crumbs-theme')).toBe(false)
  })

  it('lets the cookie win over an older saved choice', async () => {
    const { document } = browser({ theme: 'light', saved: 'dark' })

    expect(await render()).toContain('aria-checked="true"')
    expect(document.cookie).toBe('')
  })
})
