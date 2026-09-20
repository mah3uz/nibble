import { Editor } from '@tiptap/core'
import { Markdown } from '@tiptap/markdown'
import { describe, expect, it } from 'vitest'
import { postExtensions } from '../tiptap/extensions'
import { clampHeadings, looksLikeMarkdown } from '../tiptap/markdownPaste'
import { readingTime } from '../tiptap/readingTime'

describe('looksLikeMarkdown', () => {
  it('converts plain-text markdown so pasted notes keep their structure', () => {
    expect(looksLikeMarkdown('## Rates\n\n- fixed\n- variable', '')).toBe(true)
    expect(looksLikeMarkdown('Compare **fixed** rates', '')).toBe(true)
  })

  it('leaves formatted HTML from web pages and docs to the normal paste path', () => {
    expect(looksLikeMarkdown('## Rates', '<h2>Rates</h2>')).toBe(false)
  })

  it('treats code-editor clipboard HTML (styled spans only) as markdown', () => {
    expect(looksLikeMarkdown('# Title', '<div style="color:red"><span># Title</span></div>')).toBe(true)
  })

  it('does not reformat ordinary prose', () => {
    expect(looksLikeMarkdown('Home loans from 5.99% p.a. - apply today', '')).toBe(false)
  })
})

describe('clampHeadings', () => {
  it('maps markdown h1/h5 into the h2–h4 levels the site renders', () => {
    const doc = clampHeadings(
      {
        type: 'doc',
        content: [
          { type: 'heading', attrs: { level: 1 } },
          { type: 'bulletList', content: [{ type: 'listItem', content: [{ type: 'heading', attrs: { level: 6 } }] }] },
        ],
      },
      2,
      4,
    )
    expect(doc.content?.[0]?.attrs?.level).toBe(2)
    expect(doc.content?.[1]?.content?.[0]?.content?.[0]?.attrs?.level).toBe(4)
  })

  it('parses pasted markdown into nodes the post schema accepts', () => {
    const editor = new Editor({
      extensions: [...postExtensions, Markdown],
      content: { type: 'doc', content: [{ type: 'paragraph' }] },
    })
    const parsed = clampHeadings(editor.markdown!.parse('# Title\n\n**bold** and [link](https://example.com)'), 2, 4)
    expect(() => editor.schema.nodeFromJSON(parsed).check()).not.toThrow()
    expect(parsed.content?.[0]).toMatchObject({ type: 'heading', attrs: { level: 2 } })
    editor.destroy()
  })
})

describe('readingTime', () => {
  const doc = (words: number, images: number) =>
    new Editor({
      extensions: postExtensions,
      content: {
        type: 'doc',
        content: [
          { type: 'paragraph', content: words ? [{ type: 'text', text: Array(words).fill('word').join(' ') }] : [] },
          ...Array.from({ length: images }, () => ({ type: 'image', attrs: { src: '/x.jpg', alt: 'x' } })),
        ],
      },
    }).state.doc

  it('reads 265 words per minute', () => {
    expect(readingTime(doc(265, 0))).toBe('01:00')
  })

  it('counts words across block boundaries rather than gluing them together', () => {
    const paragraphs = Array.from({ length: 265 }, () => ({
      type: 'paragraph',
      content: [{ type: 'text', text: 'word' }],
    }))
    const editor = new Editor({ extensions: postExtensions, content: { type: 'doc', content: paragraphs } })
    expect(readingTime(editor.state.doc)).toBe('01:00')
    editor.destroy()
  })

  it('gives each later image less time: 12s + 11s for two images', () => {
    expect(readingTime(doc(0, 2))).toBe('00:23')
  })
})
