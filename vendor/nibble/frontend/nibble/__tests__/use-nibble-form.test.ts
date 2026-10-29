import { afterEach, describe, expect, it, vi } from 'vitest'
import cases from '../../../../../test/fixtures/files/nibble_conditions.json'
import { KEYS, parse } from '../../nibble-cp/conditions'
import type { NibbleForm, NibbleFormConditions, NibbleFormField } from '../types'

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

  it("posts the form's signed timestamp back, so the server can tell a bot that answered too fast", async () => {
    const fetch = vi.fn().mockResolvedValue({ ok: true, json: async () => ({}) })
    vi.stubGlobal('fetch', fetch)
    vi.stubGlobal('HTMLFormElement', class {})
    const { useNibbleForm } = await import('../useNibbleForm')

    await useNibbleForm({ ...definition(null), timestamp: 'signed-time' }).submit()

    expect((fetch.mock.calls[0][1].body as FormData).get('_nibble_t')).toBe('signed-time')
  })
})

type Case = { description: string; config: Record<string, unknown>; values: Record<string, unknown>; visible: boolean }

const field = (extra: Record<string, unknown> = {}) =>
  ({
    handle: 'company',
    type: 'text',
    display: 'Company',
    instructions: null,
    required: false,
    ...extra,
  }) as NibbleFormField

const form = (fields: NibbleFormField[], extra: Partial<NibbleForm> = {}): NibbleForm => ({
  ...definition(null),
  fields,
  ...extra,
})

// The server sends a field's conditions as Nibble::Conditions.describe does: the parsed rules of its first key.
function described(config: Record<string, unknown>): NibbleFormConditions | undefined {
  const key = KEYS.find((candidate) => config[candidate])
  if (!key) return undefined
  return {
    show: !key.startsWith('unless') && !key.startsWith('hide_when'),
    match: key.includes('any') ? 'any' : 'all',
    rules: parse(config[key] as Record<string, unknown>) as NibbleFormConditions['rules'],
  }
}

describe('isFieldVisible', () => {
  const plain = (cases as (Case & Record<string, unknown>)[]).filter(
    (example) =>
      !example.path &&
      !example.prefix &&
      !example.root_values &&
      !/custom|\$parent/.test(JSON.stringify(example.config)) &&
      Object.values(example.config).every((value) => typeof value !== 'string'),
  )

  it('is checked against most of the cases the server is tested against', () => {
    expect(plain.length).toBeGreaterThan(30)
  })

  for (const example of plain) {
    it(`agrees with the server: ${example.description}`, async () => {
      const { isFieldVisible } = await import('../useNibbleForm')
      expect(isFieldVisible(field({ conditions: described(example.config) }), example.values)).toBe(example.visible)
    })
  }

  it('draws a field whose condition is custom, because only the server can run it, and the server decides', async () => {
    const { isFieldVisible } = await import('../useNibbleForm')
    const conditions: NibbleFormConditions = {
      show: false,
      match: 'all',
      rules: [{ field: null, operator: 'custom', value: 'weekday' }],
    }
    expect(isFieldVisible(field({ conditions }), {})).toBe(true)
  })
})

describe('useNibbleForm values and body', () => {
  const company = field({
    conditions: { show: true, match: 'all', rules: [{ field: 'kind', operator: 'equals', value: 'business' }] },
  })
  const kind = field({ handle: 'kind', type: 'radio', options: [] })
  const source = field({ handle: 'source', hidden: true, value: 'spring-ad', default: 'spring-ad' })

  async function posted(definition: NibbleForm, change: (values: Record<string, unknown>) => void = () => {}) {
    const bodies: FormData[] = []
    vi.stubGlobal('HTMLFormElement', class {})
    vi.stubGlobal('fetch', async (_url: string, init: { body: FormData }) => {
      bodies.push(init.body)
      return { ok: true, status: 201, json: async () => ({ ok: true }) }
    })
    const { useNibbleForm } = await import('../useNibbleForm')
    const contact = useNibbleForm(definition)
    change(contact.values)
    await contact.submit()
    return Object.fromEntries(bodies[0]!.entries())
  }

  it("leaves a field hidden by its condition out of the post, so a visitor's stray answer isn't sent", async () => {
    const person = await posted(form([kind, company]), (values) =>
      Object.assign(values, { kind: 'person', company: 'Acme' }),
    )
    const business = await posted(form([kind, company]), (values) =>
      Object.assign(values, { kind: 'business', company: 'Acme' }),
    )

    expect(person).not.toHaveProperty('company')
    expect(business).toMatchObject({ company: 'Acme' })
  })

  it('posts a hidden field with its value', async () => {
    expect(await posted(form([source]))).toMatchObject({ source: 'spring-ad' })
  })

  it('starts from what the visitor sent after a refused post without JavaScript, except hidden and file fields', async () => {
    const { useNibbleForm } = await import('../useNibbleForm')
    const contact = useNibbleForm(
      form(
        [
          kind,
          company,
          source,
          field({ handle: 'consent', type: 'toggle' }),
          field({ handle: 'topics', type: 'checkboxes', options: [] }),
          field({ handle: 'cv', type: 'files' }),
        ],
        {
          result: {
            handle: 'contact',
            status: 'invalid',
            errors: { company: 'The company field is required.' },
            values: { kind: 'business', company: 'Acme', source: 'other', consent: 'true', topics: 'events', cv: 'x' },
          },
        },
      ),
    )

    expect({ ...contact.values }).toEqual({
      kind: 'business',
      company: 'Acme',
      source: 'spring-ad',
      consent: true,
      topics: ['events'],
      cv: [],
    })
    expect(contact.errorList.value).toEqual([
      { handle: 'company', label: 'Company', message: 'The company field is required.', href: '#contact-company' },
    ])
  })

  it('links each input to its help and its error, so a screen reader says why it was refused', async () => {
    const { useNibbleForm } = await import('../useNibbleForm')
    const files = field({ handle: 'cv', type: 'files', extensions: ['pdf', 'doc'], max_file_size: 5, max_files: 2 })
    const contact = useNibbleForm(form([company, files, kind]))
    contact.errors.value = { cv: 'Too big.' }

    expect(contact.describedBy(files)).toBe('contact-cv-help contact-cv-error')
    expect(contact.describedBy(company)).toBeUndefined()
    expect(contact.fileLimits(files)).toBe('PDF or DOC, up to 5 MB each, at most 2 files.')
    expect(contact.fileLimits(field({ type: 'files' }))).toBe('One file.')
  })
})
