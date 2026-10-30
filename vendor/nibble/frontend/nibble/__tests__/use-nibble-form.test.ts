import { afterEach, describe, expect, expectTypeOf, it, vi } from 'vitest'
import cases from '../../../../../test/fixtures/files/nibble_conditions.json'
import { KEYS, parse } from '../../nibble-cp/conditions'
import type { NibbleForm, NibbleFormConditions, NibbleFormField, NibbleFormValue } from '../types'
import type { useNibbleForm } from '../useNibbleForm'

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

describe('isFieldRequired', () => {
  const phone: NibbleFormConditions = {
    show: true,
    match: 'all',
    rules: [{ field: 'by', operator: 'equals', value: 'phone' }],
  }

  it('is required only while its condition passes', async () => {
    const { isFieldRequired } = await import('../useNibbleForm')
    const number = field({ required: phone })
    expect(isFieldRequired(number, { by: 'phone' })).toBe(true)
    expect(isFieldRequired(number, { by: 'email' })).toBe(false)
    expect(isFieldRequired(field({ required: { ...phone, show: false } }), { by: 'email' })).toBe(true)
  })

  it('keeps a plain true or false as it is, and leaves a custom condition to the server', async () => {
    const { isFieldRequired } = await import('../useNibbleForm')
    expect(isFieldRequired(field({ required: true }), {})).toBe(true)
    expect(isFieldRequired(field({ required: false }), {})).toBe(false)
    const rules: NibbleFormConditions['rules'] = [{ field: null, operator: 'custom', value: 'x' }]
    expect(isFieldRequired(field({ required: { show: true, match: 'all', rules } }), {})).toBe(false)
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

describe('useNibbleForm unavailable', () => {
  it('is true only for a form that needs a CAPTCHA the site has not set up', async () => {
    const { useNibbleForm } = await import('../useNibbleForm')
    const unavailable = (captcha: NibbleForm['captcha']) => useNibbleForm(definition(captcha)).unavailable

    expect(unavailable({ provider: null, site_key: null })).toBe(true)
    expect(unavailable({ provider: 'turnstile', site_key: 'key' })).toBe(false)
    expect(unavailable(null)).toBe(false)
    mounted.length = 0
  })
})

describe('useNibbleForm steps and saving for later', () => {
  const email = field({ handle: 'email', required: true })
  const kind = field({ handle: 'kind', type: 'radio', options: [] })
  const company = field({
    handle: 'company',
    conditions: { show: true, match: 'all', rules: [{ field: 'kind', operator: 'equals', value: 'business' }] },
  })
  const cv = field({ handle: 'cv', type: 'files' })
  const note = field({ handle: 'note' })
  const stepped = (extra: Partial<NibbleForm> = {}) =>
    form([email, kind, company, cv, note], {
      steps: true,
      sections: [
        { display: 'You', instructions: null, fields: ['email', 'kind'] },
        { display: 'Business', instructions: null, fields: ['company'] },
        { display: 'Files', instructions: null, fields: ['cv'] },
        { display: 'Anything else', instructions: null, fields: ['note'] },
      ],
      ...extra,
    })

  type Answer = { status: number; body?: Record<string, unknown> }
  const calls: { url: string; body: Record<string, FormDataEntryValue> }[] = []

  async function start(definition: NibbleForm, answers: Answer[] = []) {
    calls.length = 0
    vi.stubGlobal('HTMLFormElement', class {})
    vi.stubGlobal('window', { location: { pathname: '/apply' } })
    vi.stubGlobal('fetch', async (url: string, init: { body: FormData }) => {
      calls.push({ url, body: Object.fromEntries(init.body.entries()) })
      const answer = answers.shift() ?? { status: 200 }
      return { ok: answer.status < 300, status: answer.status, json: async () => answer.body ?? { ok: true } }
    })
    const { useNibbleForm } = await import('../useNibbleForm')
    const contact = useNibbleForm(definition)
    mounted.splice(0).forEach((fn) => fn())
    return contact
  }

  it('checks only the current step with the server before moving on, and stays on it with its errors', async () => {
    const contact = await start(stepped(), [{ status: 422, body: { errors: { email: ['Required.'] } } }])

    await contact.next()
    expect(calls.map((call) => call.url)).toEqual(['/forms/contact/steps/0'])
    expect(contact.step.value).toBe(0)
    expect(contact.errors.value).toEqual({ email: 'Required.' })

    await contact.next()
    expect(contact.step.value).toBe(1)
    expect(contact.errors.value).toEqual({})
  })

  it("skips a step whose fields its conditions hide, so a visitor isn't shown an empty page", async () => {
    const contact = await start(stepped())

    expect(contact.steps.value.map((step) => step.display)).toEqual(['You', 'Files', 'Anything else'])
    contact.values.kind = 'business'
    expect(contact.steps.value.map((step) => step.display)).toEqual(['You', 'Business', 'Files', 'Anything else'])
  })

  it('reports progress, goes back without a check, and shows only the current step', async () => {
    const contact = await start(stepped())

    expect(contact.progress.value).toBeCloseTo(1 / 3)
    await contact.next()
    await contact.next()
    expect([contact.step.value, contact.isLastStep.value, contact.progress.value]).toEqual([2, true, 1])
    expect([0, 2, 3].map((index) => contact.isCurrentStep(index))).toEqual([false, false, true])

    contact.back()
    expect(contact.step.value).toBe(1)
    expect(calls).toHaveLength(2)
  })

  it('sends a step only the files it asks for, so a later step check never uploads them again', async () => {
    const contact = await start(stepped())
    contact.values.cv = [new File(['%PDF'], 'cv.pdf')]

    await contact.next()
    await contact.next()

    expect(calls[0]!.body).not.toHaveProperty(['cv[]'])
    expect(calls[1]!.body).toHaveProperty(['cv[]'])
  })

  it('pressing Enter before the last step checks the step instead of sending the form', async () => {
    const contact = await start(stepped())

    await contact.submit()

    expect(calls.map((call) => call.url)).toEqual(['/forms/contact/steps/0'])
    expect(contact.step.value).toBe(1)
  })

  it('moves to the step holding a field and focuses it when an error link to it is followed', async () => {
    const focused: string[] = []
    const lookup = vi.fn((id: string) => ({ focus: () => focused.push(id) }))
    ;(document as unknown as { getElementById: typeof lookup }).getElementById = lookup
    const contact = await start(stepped())
    const event = { preventDefault: vi.fn() } as unknown as Event

    await contact.goToField('note', event)

    expect(contact.step.value).toBe(2)
    expect(event.preventDefault).toHaveBeenCalled()
    expect(focused).toEqual(['contact-note'])
  })

  it('opens the step with the first error when the final send is refused', async () => {
    const contact = await start(stepped(), [
      { status: 200 },
      { status: 200 },
      { status: 422, body: { errors: { email: ['Taken.'] } } },
    ])

    await contact.next()
    await contact.next()
    await contact.submit()

    expect(calls.at(-1)!.url).toBe('/forms/contact')
    expect(contact.step.value).toBe(0)
  })

  it('without JavaScript nothing is split into steps, so the whole form is there to fill in', async () => {
    const { useNibbleForm } = await import('../useNibbleForm')
    const contact = useNibbleForm(stepped())

    expect(contact.stepping.value).toBe(false)
    expect([0, 1, 2, 3].every((index) => contact.isCurrentStep(index))).toBe(true)
    expect(contact.isLastStep.value).toBe(true)
    mounted.length = 0
  })

  it('saves for later without files, and the final send tells the server which save to delete', async () => {
    const resume = { email: 'email', days: 7, token: null }
    const contact = await start(stepped({ resume }), [
      { status: 200, body: { ok: true, message: 'Check your email.', token: 'new-token' } },
    ])
    Object.assign(contact.values, { email: 'ada@example.test', cv: [new File(['%PDF'], 'cv.pdf')] })

    const savedEl = { focus: vi.fn() }
    contact.savedEl.value = savedEl as unknown as HTMLElement
    await contact.saveForLater()
    expect(savedEl.focus).toHaveBeenCalled()
    expect(calls[0]!.url).toBe('/forms/contact/resume')
    expect(calls[0]!.body).toMatchObject({ email: 'ada@example.test', _nibble_page: '/apply' })
    expect(calls[0]!.body).not.toHaveProperty(['cv[]'])
    expect(contact.saved.value).toBe('Check your email.')

    contact.step.value = 2
    await contact.submit()
    expect(calls.at(-1)!.body).toMatchObject({ _nibble_resume: 'new-token' })
  })

  it('starts from what was saved when the visitor follows the link', async () => {
    const contact = await start(
      stepped({
        resume: { email: 'email', days: 7, token: 'saved' },
        result: { handle: 'contact', status: 'resumed', values: { email: 'ada@example.test', kind: 'person' } },
      }),
    )

    expect(contact.values).toMatchObject({ email: 'ada@example.test', kind: 'person' })
    expect(contact.errors.value).toEqual({})
  })
})

describe('options narrowed by a parent choice', () => {
  const section = field({
    handle: 'section',
    type: 'checkboxes',
    options: [
      { value: 'billing', label: 'Billing' },
      { value: 'support', label: 'Support' },
    ],
  })
  const page = field({
    handle: 'page',
    type: 'select',
    parent: 'section',
    options: [
      { value: 'invoices', label: 'Invoices', parents: ['billing'] },
      { value: 'outages', label: 'Outages', parents: ['support'] },
      { value: 'contact', label: 'Contact', parents: ['billing', 'support'] },
    ],
  })

  it('offers only the options of a chosen parent, any of several, and none before one is chosen', async () => {
    const { optionsFor } = await import('../useNibbleForm')
    const values = (chosen: string[]) => optionsFor(page, { section: chosen }).map((option) => option.value)

    expect(values([])).toEqual([])
    expect(values(['billing'])).toEqual(['invoices', 'contact'])
    expect(values(['billing', 'support'])).toEqual(['invoices', 'outages', 'contact'])
    expect(optionsFor(section, {})).toEqual(section.options)
  })

  it("clears an answer that no longer fits when the parent changes, so the visitor can't send a pairing the server refuses", async () => {
    const { useNibbleForm } = await import('../useNibbleForm')
    const contact = useNibbleForm(form([section, page]))
    const values = contact.values as Record<string, unknown>

    values.section = ['billing']
    values.page = 'contact'
    values.section = ['support']
    expect(values.page).toBe('contact')

    values.page = 'outages'
    values.section = ['billing']
    expect(values.page).toBe('')
  })

  it('draws every option before JavaScript runs, so the form still works without it', async () => {
    const { useNibbleForm } = await import('../useNibbleForm')
    mounted.length = 0
    const contact = useNibbleForm(form([section, page]))

    expect(contact.options(page)).toHaveLength(3)
    mounted.splice(0).forEach((fn) => fn())
    expect(contact.options(page)).toEqual([])
  })
})

describe('useNibbleForm value types', () => {
  type ContactValues = { name: string; topic: 'sales' | 'support' | ''; files: File[] }
  type Form = ReturnType<typeof useNibbleForm<ContactValues>>

  it('types values from the form definition it is given', () => {
    expectTypeOf<Form['values']['topic']>().toEqualTypeOf<'sales' | 'support' | ''>()
    expectTypeOf<Form['values']['files']>().toEqualTypeOf<File[]>()
  })

  it('still accepts a typed form where an untyped one is expected', () => {
    expectTypeOf<NibbleForm<ContactValues>>().toExtend<NibbleForm>()
    expectTypeOf<NibbleForm>().toExtend<NibbleForm<Record<string, NibbleFormValue>>>()
  })
})
