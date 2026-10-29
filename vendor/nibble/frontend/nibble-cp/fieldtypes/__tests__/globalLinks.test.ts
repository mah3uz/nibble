import { Editor } from '@tiptap/core'
import StarterKit from '@tiptap/starter-kit'
import { describe, expect, it } from 'vitest'
import {
  GlobalLinkRef,
  linkAttributes,
  parseGlobalRef,
  type GlobalLinkSet,
  type LinkDialog,
} from '../rich-text/globalLinks'

const sets: GlobalLinkSet[] = [
  {
    handle: 'site',
    title: 'Site',
    fields: [{ handle: 'apply_url', display: 'Apply URL', address: 'https://example.com/apply' }],
  },
]
const dialog = (overrides: Partial<LinkDialog>): LinkDialog => ({
  mode: 'url',
  href: '',
  choice: { set: '', field: '' },
  newWindow: false,
  ...overrides,
})

function linked(attributes: ReturnType<typeof linkAttributes>) {
  const editor = new Editor({
    extensions: [StarterKit, GlobalLinkRef],
    content: { type: 'doc', content: [{ type: 'paragraph', content: [{ type: 'text', text: 'Apply' }] }] },
  })
  editor.chain().selectAll().setLink(attributes!).run()
  const mark = editor.getJSON().content?.[0]?.content?.[0]?.marks?.[0]
  editor.destroy()
  return mark
}

describe('the rich-text link dialog', () => {
  it('choosing a global field saves its reference beside the address it holds now, so the site can follow it', () => {
    const mark = linked(linkAttributes(dialog({ mode: 'global', choice: { set: 'site', field: 'apply_url' } }), sets))

    expect(mark?.attrs).toMatchObject({ href: 'https://example.com/apply', ref: 'global:site.apply_url' })
    expect(parseGlobalRef(mark?.attrs?.ref)).toEqual({ set: 'site', field: 'apply_url' })
  })

  it('a typed URL is a plain link with no reference, so it never follows a global', () => {
    const mark = linked(linkAttributes(dialog({ href: '/pricing', newWindow: true }), sets))

    expect(mark?.attrs).toMatchObject({ href: '/pricing', ref: null, target: '_blank' })
  })

  it('a global field that is no longer offered applies nothing rather than a link to nowhere', () => {
    expect(linkAttributes(dialog({ mode: 'global', choice: { set: 'site', field: 'gone' } }), sets)).toBeNull()
    expect(linkAttributes(dialog({ href: '' }), sets)).toBeNull()
  })

  it('reads only well-formed references', () => {
    expect(parseGlobalRef('global:site')).toBeNull()
    expect(parseGlobalRef('https://example.com')).toBeNull()
    expect(parseGlobalRef(null)).toBeNull()
  })
})
