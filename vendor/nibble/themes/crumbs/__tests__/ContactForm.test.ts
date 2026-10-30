import { readFileSync } from 'node:fs'
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

const PUBLIC_FIELDTYPES = readFileSync(new URL('../../../lib/nibble/forms.rb', import.meta.url), 'utf8')
  .match(/PUBLIC_FIELDTYPES = %w\[([^\]]+)\]/)![1]!
  .split(/\s+/)

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

  it('draws a form with steps whole on the server, so without JavaScript it is one long form that sends as usual', async () => {
    const html = await render(
      form({
        steps: true,
        resume: { email: 'name', days: 7, token: null },
        sections: [
          { display: 'Your details', instructions: null, fields: ['name', 'budget'] },
          { display: 'The visit', instructions: null, fields: ['note'] },
        ],
      }),
    )

    expect(html.match(/<fieldset[^>]*>/g)).toHaveLength(2)
    expect(html).not.toContain('display:none')
    expect(html).not.toContain('Step 1 of 2')
    expect(html).toMatch(/<button type="submit"[^>]*>\s*Send message/)
    expect(html).not.toMatch(/>\s*(Back|Next|Save and finish later)\s*</)
  })

  it('carries a resumed form’s token, so sending it without JavaScript deletes what was saved', async () => {
    const html = await render(
      form({
        resume: { email: 'name', days: 7, token: 'saved-token' },
        result: { handle: 'visit', status: 'resumed', values: { name: 'Ada' } },
      }),
    )

    expect(html).toMatch(/<input type="hidden" name="_nibble_resume" value="saved-token">/)
    expect(tag(html, 'visit-name')).toContain('value="Ada"')
    expect(html).not.toContain('role="alert"')
  })

  it('carries the signed timestamp of a paced form, so a post without JavaScript is not taken for a bot', async () => {
    expect(await render(form({ timestamp: 'signed-at' }))).toMatch(
      /<input type="hidden" name="_nibble_t" value="signed-at">/,
    )
    expect(await render(form({ timestamp: null }))).not.toContain('_nibble_t')
  })

  it('says so when a resume link has expired', async () => {
    const html = await render(
      form({
        resume: { email: 'name', days: 7, token: null },
        result: { handle: 'visit', status: 'expired', message: 'This link has expired.' },
      }),
    )

    expect(html).toMatch(/<p role="status"[^>]*>\s*This link has expired./)
  })

  it('draws a flat form with no fieldset, and prepend and append beside the input', async () => {
    const html = await render(form({}))

    expect(html).not.toContain('<fieldset')
    expect(html.match(/<label/g)).toHaveLength(3)
    expect(html).toMatch(/<span>\$<\/span>\s*<input[^>]*id="visit-budget"[^>]*>\s*<span>per head<\/span>/)
  })

  it('lets an input with prepend or append shrink inside its column, so a narrow screen never scrolls sideways', async () => {
    const html = await render(
      form({
        fields: [
          field('budget', { type: 'integer', prepend: '$', append: 'per head' }),
          field('rate', { type: 'range', append: '%' }),
        ],
      }),
    )

    expect(tag(html, 'visit-budget')).toContain('w-0 min-w-0')
    expect(tag(html, 'visit-rate')).toContain('w-0 min-w-0')
    expect(html).toContain('grid-cols-[minmax(0,1fr)]')
  })

  it('looks disabled when the button is, and gives the saved message focus and a gap under section headings', async () => {
    const html = await render(
      form({
        resume: { email: 'email', days: 7, token: null },
        sections: [{ display: 'Details', instructions: 'Hello.', fields: ['name', 'budget', 'note'] }],
      }),
    )

    expect(html).toMatch(/<button type="submit"[^>]*disabled:opacity-40/)
    expect(html).toMatch(/<p[^>]*role="status" tabindex="-1"[^>]*empty:hidden/)
    expect(html).toMatch(/<p class="mt-2 [^"]*">Hello\./)
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
      field('price', { type: 'decimal', decimals: 2 }),
      field('mood', { type: 'range', min: 1, max: 9 }),
      field('stars', { type: 'rating', display: 'Stars', max: 3 }),
      field('consent', { type: 'toggle', display: 'Consent', inline_label: 'I agree to be contacted' }),
      field('size', { type: 'select', options, required: true }),
      field('extras', { type: 'select', options, multiple: true }),
      field('group', { type: 'radio', display: 'Group size', options, required: true }),
      field('topics', { type: 'checkboxes', display: 'Topics', options }),
      field('day', { type: 'date', earliest_date: '2026-11-01', latest_date: '2026-12-31' }),
      field('arrival', { type: 'date', time_enabled: true, earliest_date: '2026-11-01' }),
      field('files', { type: 'files', extensions: ['pdf', 'jpg'], max_file_size: 5, max_files: 3 }),
      field('total', { type: 'calculation', formula: '{guests} * 10' }),
      field('notice', { type: 'note', text_html: '<p>We reply within a day.</p>' }),
      field('opens', { type: 'time', seconds: true, earliest: '09:00', latest: '17:30' }),
      field('brand', { type: 'color', swatches: ['#1a2b3c'], allow_any: true }),
      field('delivery', { type: 'button_group', display: 'Delivery', options }),
    ]
    const html = await render(form({ fields }))

    expect(PUBLIC_FIELDTYPES.length).toBeGreaterThan(16)
    expect(new Set(fields.map((item) => item.type))).toEqual(new Set(PUBLIC_FIELDTYPES))
    expect(tag(html, 'visit-name')).toMatch(/type="text"[^>]*autocomplete="name"/)
    expect(tag(html, 'visit-message')).toMatch(/^<textarea[^>]*rows="3"/)
    expect(tag(html, 'visit-guests')).toContain('type="number"')
    expect(tag(html, 'visit-price')).toMatch(/type="number"(?=[^>]*inputmode="decimal")/)
    expect(tag(html, 'visit-mood')).toMatch(/type="range"(?=[^>]*min="1")(?=[^>]*max="9")/)
    expect(html.match(/type="radio"[^>]*name="stars"/g)).toHaveLength(3)
    expect(tag(html, 'visit-consent')).toMatch(/type="checkbox"[^>]*value="true"/)
    expect(html).toMatch(/<label[^>]*for="visit-consent">(<!--\[-->)?\s*I agree to be contacted/)
    expect(tag(html, 'visit-size')).toMatch(/^<select(?=[^>]*required)/)
    expect(html).toMatch(/<option value disabled selected>\s*Choose one…/)
    expect(tag(html, 'visit-extras')).toMatch(/^<select(?=[^>]*multiple)(?=[^>]*name="extras\[\]")/)

    const [, group, topics] = html.match(/<fieldset[\s\S]*?<\/fieldset>/g) ?? []
    expect(group).toMatch(
      /<legend[^>]*>\s*Group size(<!--\[-->)?<span[^>]*aria-hidden="true"> \*<\/span><span class="sr-only"> \(required\)/,
    )
    expect(group!.match(/type="radio"[^>]*name="group"[^>]*value="(small|large)"/g)).toHaveLength(2)
    expect(group).toMatch(/<label[^>]*><input[^>]*value="small"[^>]*> 2–10<\/label>/)
    expect(topics!.match(/type="checkbox"[^>]*name="topics\[\]"/g)).toHaveLength(2)

    expect(tag(html, 'visit-day')).toMatch(/type="date"(?=[^>]*min="2026-11-01")(?=[^>]*max="2026-12-31")/)
    expect(tag(html, 'visit-arrival')).toMatch(/type="datetime-local"[^>]*min="2026-11-01T00:00"/)
    expect(html).not.toMatch(/arrival[^<]*<span[^>]*> \(/)
    expect(tag(html, 'visit-files')).toMatch(/type="file"(?=[^>]*accept=".pdf,.jpg")(?=[^>]*multiple)/)
    expect(tag(html, 'visit-files-help')).toBeTruthy()
    expect(html).toContain('PDF or JPG, up to 5 MB each, at most 3 files.')
    expect(tag(html, 'visit-total')).toMatch(/^<output/)
    expect(html).toContain('<p>We reply within a day.</p>')
    expect(tag(html, 'visit-opens')).toMatch(/type="time"(?=[^>]*step="1")(?=[^>]*min="09:00")(?=[^>]*max="17:30")/)
    expect(tag(html, 'visit-brand')).toMatch(/type="color"[^>]*list="visit-brand-swatches"/)
    expect(html).toMatch(/<datalist id="visit-brand-swatches">\s*(<!--\[-->)?<option value="#1a2b3c">/)
  })

  it('draws a consent link inside the checkbox label, and a note as text with no control or name', async () => {
    const html = await render(
      form({
        fields: [
          field('consent', {
            type: 'toggle',
            required: true,
            inline_label: 'I agree to the privacy policy',
            inline_label_html:
              'I agree to the <a href="/privacy" rel="noopener noreferrer" target="_blank">privacy policy</a>',
          }),
          field('notice', { type: 'note', text_html: '<p>Replies take a day.</p>' }),
        ],
      }),
    )

    expect(html).toMatch(
      /<label[^>]*for="visit-consent">[\s\S]*<a href="\/privacy" rel="noopener noreferrer" target="_blank">privacy policy<\/a>/,
    )
    expect(html).toContain('<p>Replies take a day.</p>')
    expect(html).not.toContain('name="notice"')
    expect(html).not.toContain('for="visit-notice"')
  })

  it("names a date-time's zone in its label, so a visitor knows whose clock they are typing in", async () => {
    const html = await render(
      form({ fields: [field('starts', { type: 'date', time_enabled: true, time_zone: 'Australia/Sydney' })] }),
    )

    expect(html).toMatch(
      /<label for="visit-starts"[^>]*>\s*starts(<!--[^>]*-->)*<span[^>]*> \(Australia\/Sydney\)<\/span>/,
    )
  })

  it('draws a button group, and a colour limited to swatches, as radios a keyboard and a screen reader use as radios', async () => {
    const fields = [
      field('delivery', { type: 'button_group', display: 'Delivery', options }),
      field('brand', { type: 'color', display: 'Brand', swatches: ['#1a2b3c', '#ffaa00'], allow_any: false }),
    ]
    const html = await render(form({ fields }))

    const [delivery, brand] = html.match(/<fieldset[\s\S]*?<\/fieldset>/g) ?? []
    expect(delivery).toMatch(/<legend[^>]*>\s*Delivery/)
    expect(
      delivery!.match(
        /<input[^>]*type="radio"[^>]*name="delivery"[^>]*value="(small|large)"[^>]*class="peer sr-only"/g,
      ),
    ).toHaveLength(2)
    expect(delivery).toContain('2–10')
    expect(brand!.match(/type="radio"[^>]*name="brand"[^>]*value="#(1a2b3c|ffaa00)"/g)).toHaveLength(2)
    expect(brand).toMatch(/background-color:#ffaa00;[^>]*aria-hidden="true"/)
    expect(brand).toContain('#ffaa00</span>')
    expect(html).not.toContain('type="color"')
  })

  it('shows a calculation as read-only output that screen readers hear change, and posts nothing for it', async () => {
    const html = await render(
      form({
        fields: [
          field('quantity', { type: 'integer', default: 3 }),
          field('unit_price', { type: 'integer', hidden: true, value: 400, default: 400 }),
          field('total', { type: 'calculation', formula: '{quantity} * {unit_price} + 50', decimals: 2, prepend: '$' }),
        ],
      }),
    )

    expect(html).toMatch(/<label for="visit-total"[^>]*>\s*total/)
    expect(html).toMatch(/<output id="visit-total" aria-live="polite"[^>]*>\$1,250\.00<\/output>/)
    expect(tag(html, 'visit-total')).not.toContain('name=')
  })

  it('sends a hidden field without drawing a label for it', async () => {
    const html = await render(
      form({ fields: [field('source', { hidden: true, value: 'spring-ad', default: 'spring-ad' })] }),
    )

    expect(html).toMatch(/<input[^>]*type="hidden"[^>]*name="source"[^>]*value="spring-ad"/)
    expect(html).not.toContain('<label')
  })

  it('marks a conditionally required field only while its condition holds', async () => {
    const phone = field('phone', {
      required: { show: true, match: 'all', rules: [{ field: 'by', operator: 'equals', value: 'phone' }] },
    })
    const by = (value: string) => field('by', { type: 'radio', options: [{ value, label: value }], default: value })

    const needed = await render(form({ fields: [by('phone'), phone] }))
    expect(tag(needed, 'visit-phone')).toContain('required')
    expect(needed).toContain('Fields marked')

    const optional = await render(form({ fields: [by('email'), phone] }))
    expect(tag(optional, 'visit-phone')).not.toContain('required')
    expect(optional).not.toContain('Fields marked')
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

    expect(html).toMatch(/<div tabindex="-1"/)
    expect(html).not.toContain('role="alert"')
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
    expect(html).not.toContain('<form')
  })

  it('says a form that needs an unconfigured CAPTCHA cannot be sent, and disables the button, before anything is typed', async () => {
    const html = await render(
      form({
        captcha: { provider: null, site_key: null },
        messages: { too_large: '', generic: '', network: '', unavailable: 'Not taking messages today.' },
      }),
    )

    expect(html).toMatch(/<p role="status"[^>]*>\s*Not taking messages today\./)
    expect(html).toMatch(/<button type="submit"[^>]*\sdisabled(="")?[\s>]/)
    expect(await render(form({ captcha: { provider: 'turnstile', site_key: 'k' } }))).not.toMatch(
      /<button type="submit"[^>]*\sdisabled(="")?[\s>]/,
    )
  })

  it('tells a visitor who followed a resume link that what they saved is back', async () => {
    const html = await render(form({ result: { handle: 'visit', status: 'resumed', values: { name: 'Ada' } } }))

    expect(html).toContain('We&#39;ve brought back what you saved. Attach any files again.')
  })

  it('numbers sections by those drawn, so a skipped conditional step leaves no gap', async () => {
    const skipped = {
      conditions: { show: true, match: 'all', rules: [{ field: 'name', operator: 'equals', value: 'x' }] },
    }
    const html = await render(
      form({
        fields: [field('name'), field('extra', skipped), field('note')],
        sections: [
          { display: 'One', instructions: null, fields: ['name'] },
          { display: 'Two', instructions: null, fields: ['extra'] },
          { display: 'Three', instructions: null, fields: ['note'] },
        ],
      }),
    )

    expect(html).toMatch(/<legend[^>]*>1\. One/)
    expect(html).toMatch(/<legend[^>]*>2\. Three/)
  })

  it('shows that a colour has not been chosen, rather than a black that sends nothing', async () => {
    const html = await render(form({ fields: [field('brand', { type: 'color', required: true })] }))

    expect(tag(html, 'visit-brand')).toContain('opacity-30')
    expect(tag(html, 'visit-brand')).not.toContain('value=')
    expect(html).toContain('Not chosen')
  })

  it('names a toggle with a heading and a label by both, and gives a range its units as text', async () => {
    const html = await render(
      form({
        fields: [
          field('agree', { type: 'toggle', display: 'Consent', inline_label: 'I agree' }),
          field('mood', { type: 'range', min: 0, max: 10, prepend: '$', append: 'k' }),
        ],
      }),
    )

    expect(tag(html, 'visit-agree')).toContain('aria-labelledby="visit-agree-display visit-agree-label"')
    expect(html).toMatch(/id="visit-agree-display"[^>]*>Consent/)
    expect(html).toMatch(/id="visit-agree-label"/)
    expect(tag(html, 'visit-mood')).toContain('aria-valuetext="$0 k"')
  })

  it('keeps the honeypot out of reach of keyboards, screen readers and autofill, so a real enquiry is not caught as spam', async () => {
    const html = await render(form({ honeypot: '_nibble_hp' }))
    const trap = html.match(/<input[^>]*name="_nibble_hp"[^>]*>/)?.[0] ?? ''

    expect(trap).toContain('tabindex="-1"')
    expect(trap).toContain('autocomplete="off"')
    expect(trap).toContain('aria-hidden="true"')
    expect(trap).toContain('-left-[9999px]')
  })

  it('shows a closed form’s message in place of the form', async () => {
    const html = await render(form({ closed: true, closed_message: 'Registration has closed.' }))

    expect(html).toMatch(/<p role="status">Registration has closed.<\/p>/)
    expect(html).not.toContain('<form')
  })

  it('words its own labels from the definition’s messages and submit_label, so they follow the page locale', async () => {
    const messages = {
      too_large: '',
      generic: '',
      network: '',
      send: 'Envoyer',
      required_note: 'Les champs * sont requis.',
    }
    const html = await render(form({ messages }))
    const labelled = await render(
      form({ messages, submit_label: 'Réserver', fields: [field('a', { required: true })] }),
    )

    expect(await render(form({ messages }))).toContain('Envoyer')
    expect(html).not.toContain('Send message')
    expect(labelled).toContain('Réserver')
    expect(labelled).toContain('Les champs')
    expect(labelled).not.toContain('Fields marked')
  })

  it('draws a decimal as a number input stepping by its scale, so the browser accepts the cents the server keeps', async () => {
    const html = await render(form({ fields: [field('price', { type: 'decimal', decimals: 2, min: 0 })] }))

    expect(tag(html, 'visit-price')).toMatch(/type="number"(?=[^>]*inputmode="decimal")(?=[^>]*step="0.01")/)
    expect(await render(form({ fields: [field('w', { type: 'decimal', decimals: 1, step: 0.5 })] }))).toContain(
      'step="0.5"',
    )
  })

  it('draws a range as a slider that starts at its minimum and shows its value beside it', async () => {
    const html = await render(
      form({ fields: [field('mood', { type: 'range', min: 10, max: 50, step: 5, append: '%' })] }),
    )

    expect(tag(html, 'visit-mood')).toMatch(/type="range"(?=[^>]*min="10")(?=[^>]*max="50")(?=[^>]*step="5")/)
    expect(html).toMatch(/<output for="visit-mood"[^>]*>10<\/output>/)
  })

  it('draws a rating as a radio group of stars each named for a screen reader, with the chosen ones lit', async () => {
    const html = await render(
      form({ fields: [field('stars', { type: 'rating', max: 4, display: 'Rate us', default: 2 })] }),
    )
    const group = html.match(/<fieldset[\s\S]*?<\/fieldset>/)![0]

    expect(group).toMatch(/<legend[^>]*>\s*Rate us/)
    expect(group.match(/type="radio"[^>]*name="stars"/g)).toHaveLength(4)
    expect(group).toContain('3 of 4')
    expect(group.match(/text-accent/g)).toHaveLength(2)
    expect(group).toMatch(/type="radio"(?=[^>]*value="2")[^>]*checked/)
  })
})
