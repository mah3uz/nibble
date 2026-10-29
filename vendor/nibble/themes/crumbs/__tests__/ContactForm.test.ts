import { createSSRApp } from 'vue'
import { renderToString } from 'vue/server-renderer'
import { describe, expect, it, vi } from 'vitest'
import ContactForm from '../components/ContactForm.vue'
import type { NibbleForm } from '@nibble'

vi.mock('@nibble', async () => {
  const { reactive, ref } = await import('vue')
  return {
    useNibbleForm: () => ({
      values: reactive({}),
      trap: ref(''),
      errors: ref({}),
      sent: ref(false),
      message: ref(null),
      processing: ref(false),
      captchaEl: ref(null),
      fieldName: (field: { handle: string }) => field.handle,
      accept: () => undefined,
      setFiles: () => {},
      submit: () => {},
    }),
  }
})

const field = (handle: string, extra = {}) => ({
  handle,
  type: 'text',
  display: handle,
  instructions: null,
  required: false,
  ...extra,
})

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
    expect(html).toMatch(/<span>\$<\/span>\s*<input[^>]*id="contact-budget"[^>]*>\s*<span>per head<\/span>/)
  })

  it('draws an integer field as a number input with min, max and step, so the browser agrees with the server', async () => {
    const html = await render(
      form({ fields: [field('amount', { type: 'integer', min: 2000, max: 10000, step: 500 })] }),
    )

    expect(html).toMatch(
      /<input(?=[^>]*type="number")(?=[^>]*inputmode="numeric")(?=[^>]*min="2000")(?=[^>]*max="10000")(?=[^>]*step="500")[^>]*>/,
    )
  })
})
