import { effectScope } from 'vue'
import { beforeEach, expect, test, vi } from 'vitest'

vi.mock('@inertiajs/vue3', () => ({
  usePage: () => ({ props: { admin: { preferences: { theme: 'system', sidebar_collapsed: false } } } }),
}))

beforeEach(() => {
  vi.resetModules()
  vi.useFakeTimers()
  vi.stubGlobal(
    'fetch',
    vi.fn(() => Promise.resolve({ ok: true })),
  )
})

// Two components calling usePreference for the same key (e.g. UserMenu's theme switcher and
// useTheme's watcher) must see one shared value — otherwise a change made in one is invisible to the
// other, which is exactly the bug this guards against.
test('two calls for the same key share one reactive value', async () => {
  const { usePreference } = await import('../preferences')
  const scope = effectScope()
  scope.run(() => {
    const a = usePreference('theme', 'system')
    const b = usePreference('theme', 'system')
    a.value = 'dark'
    expect(b.value).toBe('dark')
  })
  scope.stop()
})

test('different keys stay independent', async () => {
  const { usePreference } = await import('../preferences')
  const scope = effectScope()
  scope.run(() => {
    const theme = usePreference('theme', 'system')
    const collapsed = usePreference('sidebar_collapsed', false)
    theme.value = 'dark'
    expect(collapsed.value).toBe(false)
  })
  scope.stop()
})
