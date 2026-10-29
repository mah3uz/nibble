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
// Runs the mounted hook at once, so the server renderer draws what a browser shows once JavaScript has loaded.
vi.mock('vue', async (original) => ({
  ...(await original<typeof import('vue')>()),
  onMounted: (fn: () => void) => fn(),
}))

const field = (handle: string) =>
  ({ handle, type: 'text', display: handle, instructions: null, required: false }) as NibbleFormField

const form = (extra: Partial<NibbleForm> = {}): NibbleForm => ({
  handle: 'visit',
  title: 'Visit',
  action: '/forms/visit',
  honeypot: null,
  captcha: null,
  fields: [field('name'), field('note')],
  sections: [
    { display: 'Your details', instructions: null, fields: ['name'] },
    { display: 'The visit', instructions: null, fields: ['note'] },
  ],
  steps: true,
  success: {},
  result: null,
  ...extra,
})

const render = (definition: NibbleForm) => renderToString(createSSRApp(ContactForm, { form: definition }))

describe('crumbs ContactForm with steps', () => {
  it('shows one step at a time with where the visitor is, and a focusable step heading to announce it', async () => {
    const html = await render(form())

    expect(html).toMatch(/<p tabindex="-1"[^>]*>\s*Step 1 of 2\s*<\/p>/)
    expect(html).toContain('style="width:50%;"')
    const fieldsets = html.match(/<fieldset[^>]*>/g) ?? []
    expect(fieldsets.map((tag) => tag.includes('display:none'))).toEqual([false, true])
    expect(html).toMatch(/<button type="submit"[^>]*>\s*Next\s*<\/button>/)
    expect(html).not.toMatch(/>\s*Back\s*</)
  })

  it('offers to save and finish later only on a form with resume, with a live region for what happened', async () => {
    expect(await render(form())).not.toContain('Save and finish later')

    const html = await render(form({ resume: { email: 'name', days: 7, token: null } }))
    expect(html).toMatch(/<button type="button"[^>]*>\s*Save and finish later\s*<\/button>/)
    expect(html).toMatch(/<p role="status" class="text-sm empty:hidden">/)
  })
})
