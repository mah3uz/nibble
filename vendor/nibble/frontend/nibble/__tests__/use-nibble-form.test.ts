import { afterEach, describe, expect, it, vi } from 'vitest'
import type { NibbleForm } from '../types'

const mounted: (() => void)[] = []

vi.mock('@inertiajs/vue3', () => ({ router: {} }))
vi.mock('../composables', async () => {
  const { ref } = await import('vue')
  return { useLocale: () => ref('en') }
})
vi.mock('vue', async (original) => ({
  ...(await original<typeof import('vue')>()),
  onMounted: (fn: () => void) => mounted.push(fn),
  onBeforeUnmount: () => {},
}))

const scripts: string[] = []

vi.stubGlobal('document', {
  createElement: () => ({}),
  head: { appendChild: (script: { src: string }) => scripts.push(script.src) },
})

const definition = (captcha: NibbleForm['captcha']): NibbleForm => ({
  handle: 'contact',
  title: null,
  action: '/forms/contact',
  honeypot: null,
  captcha,
  fields: [],
  sections: null,
  success: {},
  result: null,
})

async function mount(captcha: NibbleForm['captcha']) {
  const { useNibbleForm } = await import('../useNibbleForm')
  useNibbleForm(definition(captcha))
  mounted.splice(0).forEach((fn) => fn())
}

afterEach(() => {
  scripts.length = 0
})

describe('useNibbleForm', () => {
  it("loads no widget script when the form wants a CAPTCHA the site hasn't set up, so no third party is called for nothing", async () => {
    await mount({ provider: null, site_key: null })

    expect(scripts).toEqual([])
  })

  it('loads the provider script once the keys are set', async () => {
    await mount({ provider: 'recaptcha', site_key: 'abc' })

    expect(scripts).toEqual(['https://www.google.com/recaptcha/api.js?render=abc'])
  })
})
