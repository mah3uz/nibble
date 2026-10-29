import { createSSRApp } from 'vue'
import { renderToString } from 'vue/server-renderer'
import { describe, expect, it, vi } from 'vitest'
import ContactForm from '../components/ContactForm.vue'
import type { NibbleForm, NibbleFormField } from '@nibble'

vi.mock('@nibble', () => import('../../../frontend/nibble/useNibbleForm'))
vi.mock('@inertiajs/vue3', () => ({ router: {} }))
vi.mock('../../../frontend/nibble/composables', async () => {
  const { ref } = await import('vue')
  return { useLocale: () => ref('en') }
})

const PUBLIC_FIELDTYPES = ['text', 'textarea', 'integer', 'toggle', 'select', 'radio', 'checkboxes', 'date', 'files']

const field = (handle: string, extra: Record<string, unknown> = {}) =>
  ({ handle, type: 'text', display: handle, instructions: null, required: false, ...extra }) as NibbleFormField

const options = [
  { value: 'small', label: '2–10' },
  { value: 'large', label: '11 or more' },
]

const form = (extra: Partial<NibbleForm>): NibbleForm => ({
  handle: 'visit',
  title: 'Visit',
  action: '/forms/visit',
  honeypot: null,
  captcha: null,
  fields: [field('name'), field('budget', { type: 'integer', prepend: '$', append: 'per head' }), field('note')],
  sections: null,
  success: {},
  result: null,
  ...extra,
})

const render = (definition: NibbleForm) => renderToString(createSSRApp(ContactForm, { form: definition }))
const tag = (html: string, id: string) => html.match(new RegExp(`<[a-z]+[^>]*id="${id}"[^>]*>`))?.[0] ?? ''

describe('crumbs ContactForm', () => {
  it('draws each section as a numbered fieldset with its instructions, so a long form reads in steps', async () => {
    const html = await render(
      form({
        sections: [
          { display: 'Your details', instructions: 'So we can greet you.', fields: ['name', 'budget'] },
          { display: 'The visit', instructions: null, fields: ['note'] },
        ],
      }),
    )

    const fieldsets = html.match(/<fieldset[\s\S]*?<\/fieldset>/g) ?? []
    expect(fieldsets).toHaveLength(2)
    expect(fieldsets[0]).toMatch(/<legend[^>]*>1\. Your details<\/legend>/)
    expect(fieldsets[0]).toContain('So we can greet you.')
    expect(fieldsets[0]!.match(/<label/g)).toHaveLength(2)
    expect(fieldsets[1]).toMatch(/<legend[^>]*>2\. The visit<\/legend>/)
    expect(fieldsets[1]!.match(/<label/g)).toHaveLength(1)
  })

  it('draws a flat form with no fieldset, and prepend and append beside the input', async () => {
    const html = await render(form({}))

    expect(html).not.toContain('<fieldset')
    expect(html.match(/<label/g)).toHaveLength(3)
    expect(html).toMatch(/<span>\$<\/span>\s*<input[^>]*id="visit-budget"[^>]*>\s*<span>per head<\/span>/)
  })

  it('draws an integer field as a number input with min, max and step, so the browser agrees with the server', async () => {
    const html = await render(
      form({ fields: [field('amount', { type: 'integer', min: 2000, max: 10000, step: 500 })] }),
    )

    expect(html).toMatch(
      /<input(?=[^>]*type="number")(?=[^>]*inputmode="numeric")(?=[^>]*min="2000")(?=[^>]*max="10000")(?=[^>]*step="500")[^>]*>/,
    )
  })

  it('gives every public fieldtype its own control, so a visitor never types a value into a text box', async () => {
    const fields = [
      field('name', { autocomplete: 'name' }),
      field('message', { type: 'textarea', rows: 3 }),
      field('guests', { type: 'integer' }),
      field('consent', { type: 'toggle', display: 'Consent', inline_label: 'I agree to be contacted' }),
      field('size', { type: 'select', options, required: true }),
      field('extras', { type: 'select', options, multiple: true }),
      field('group', { type: 'radio', display: 'Group size', options, required: true }),
      field('topics', { type: 'checkboxes', display: 'Topics', options }),
      field('day', { type: 'date', earliest_date: '2026-11-01', latest_date: '2026-12-31' }),
      field('arrival', { type: 'date', time_enabled: true, earliest_date: '2026-11-01' }),
      field('files', { type: 'files', extensions: ['pdf', 'jpg'], max_file_size: 5, max_files: 3 }),
    ]
    const html = await render(form({ fields }))

    expect(new Set(fields.map((item) => item.type))).toEqual(new Set(PUBLIC_FIELDTYPES))
    expect(tag(html, 'visit-name')).toMatch(/type="text"[^>]*autocomplete="name"/)
    expect(tag(html, 'visit-message')).toMatch(/^<textarea[^>]*rows="3"/)
    expect(tag(html, 'visit-guests')).toContain('type="number"')
    expect(tag(html, 'visit-consent')).toMatch(/type="checkbox"[^>]*value="true"/)
    expect(html).toMatch(/<label for="visit-consent">\s*I agree to be contacted/)
    expect(tag(html, 'visit-size')).toMatch(/^<select(?=[^>]*required)/)
    expect(html).toMatch(/<option value disabled selected>\s*Choose one…/)
    expect(tag(html, 'visit-extras')).toMatch(/^<select(?=[^>]*multiple)(?=[^>]*name="extras\[\]")/)

    const [group, topics] = html.match(/<fieldset[\s\S]*?<\/fieldset>/g) ?? []
    expect(group).toMatch(
      /<legend[^>]*>\s*Group size(<!--\[-->)?<span[^>]*aria-hidden="true"> \*<\/span><span class="sr-only"> \(required\)/,
    )
    expect(group!.match(/type="radio"[^>]*name="group"[^>]*value="(small|large)"/g)).toHaveLength(2)
    expect(group).toMatch(/<label[^>]*><input[^>]*value="small"[^>]*> 2–10<\/label>/)
    expect(topics!.match(/type="checkbox"[^>]*name="topics\[\]"/g)).toHaveLength(2)

    expect(tag(html, 'visit-day')).toMatch(/type="date"(?=[^>]*min="2026-11-01")(?=[^>]*max="2026-12-31")/)
    expect(tag(html, 'visit-arrival')).toMatch(/type="datetime-local"[^>]*min="2026-11-01T00:00"/)
    expect(tag(html, 'visit-files')).toMatch(/type="file"(?=[^>]*accept=".pdf,.jpg")(?=[^>]*multiple)/)
    expect(tag(html, 'visit-files-help')).toBeTruthy()
    expect(html).toContain('PDF or JPG, up to 5 MB each, at most 3 files.')
  })

  it('sends a hidden field without drawing a label for it', async () => {
    const html = await render(
      form({ fields: [field('source', { hidden: true, value: 'spring-ad', default: 'spring-ad' })] }),
    )

    expect(html).toMatch(/<input[^>]*type="hidden"[^>]*name="source"[^>]*value="spring-ad"/)
    expect(html).not.toContain('<label')
  })

  it('draws a conditional field only when its condition holds, as the server will judge it', async () => {
    const company = field('company', {
      conditions: { show: true, match: 'all', rules: [{ field: 'kind', operator: 'equals', value: 'business' }] },
    })
    const kind = field('kind', { type: 'radio', options: [{ value: 'business', label: 'Business' }] })

    expect(await render(form({ fields: [kind, company] }))).not.toContain('visit-company')
    expect(
      await render(form({ fields: [kind, { ...company, default: 'x' }, { ...kind, default: 'business' }] })),
    ).toContain('id="visit-company"')
  })

  it('after a refused post, lists each error at the top with a link, ties the error to its input, and keeps what was typed', async () => {
    const html = await render(
      form({
        fields: [
          field('name', { required: true }),
          field('email', { instructions: 'We reply here.' }),
          field('size', { type: 'radio', options }),
          field('plan', { type: 'select', options }),
          field('consent', { type: 'toggle' }),
        ],
        result: {
          handle: 'visit',
          status: 'invalid',
          errors: { email: 'The email must be a valid email address.' },
          values: { name: 'Ada', email: 'ada@', size: 'large', plan: 'large', consent: 'true' },
        },
      }),
    )

    expect(html).toMatch(/<div role="alert" tabindex="-1"/)
    expect(html).toMatch(/<a href="#visit-email"[^>]*>email: The email must be a valid email address.<\/a>/)
    expect(tag(html, 'visit-email')).toMatch(
      /(?=[^>]*aria-describedby="visit-email-help visit-email-error")(?=[^>]*aria-invalid="true")(?=[^>]*value="ada@")/,
    )
    expect(html).toMatch(/id="visit-email-error"[^>]*>\s*The email must be a valid email address./)
    expect(tag(html, 'visit-name')).toMatch(/(?=[^>]*required)(?=[^>]*value="Ada")/)
    expect(tag(html, 'visit-size-1')).toContain('checked')
    expect(tag(html, 'visit-consent')).toContain('checked')
    expect(html).toMatch(/<option value="large" selected>/)
    expect(tag(html, 'visit-name')).not.toContain('aria-invalid')
    expect(html).toContain('Fields marked <span class="text-accent">*</span> are required.')
  })

  it('announces the success message', async () => {
    const html = await render(
      form({ result: { handle: 'visit', status: 'sent', message: 'Thanks, we’ll be in touch.' } }),
    )

    expect(html).toMatch(/<p role="status" tabindex="-1"[^>]*>\s*Thanks, we’ll be in touch./)
  })

  it('keeps the honeypot out of reach of keyboards, screen readers and autofill, so a real enquiry is not caught as spam', async () => {
    const html = await render(form({ honeypot: '_nibble_hp' }))
    const trap = html.match(/<input[^>]*name="_nibble_hp"[^>]*>/)?.[0] ?? ''

    expect(trap).toContain('tabindex="-1"')
    expect(trap).toContain('autocomplete="off"')
    expect(trap).toContain('aria-hidden="true"')
    expect(trap).toContain('-left-[9999px]')
  })
})
