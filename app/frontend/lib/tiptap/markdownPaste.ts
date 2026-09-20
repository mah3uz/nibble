import { Extension, type JSONContent } from '@tiptap/core'
import { Plugin, PluginKey } from '@tiptap/pm/state'

const BLOCK_SYNTAX = /^(#{1,6}\s|>\s|[-*+]\s|\d+[.)]\s|```|---\s*$|\|.*\|\s*$)/m
const INLINE_SYNTAX = /(\*\*[^*\n]+\*\*|__[^_\n]+__|`[^`\n]+`|!?\[[^\]\n]*\]\([^)\n]+\)|~~[^~\n]+~~)/
// Code editors put styled spans on the clipboard; only real formatting means the source wasn't markdown.
const SEMANTIC_HTML = /<(p|h[1-6]|ul|ol|li|strong|b|em|i|a|table|blockquote|pre)[\s>]/i

export function looksLikeMarkdown(text: string, html: string): boolean {
  if (html && SEMANTIC_HTML.test(html)) return false
  return BLOCK_SYNTAX.test(text) || INLINE_SYNTAX.test(text)
}

export function clampHeadings(node: JSONContent, min: number, max: number): JSONContent {
  const level = node.type === 'heading' ? Math.min(max, Math.max(min, Number(node.attrs?.level ?? min))) : undefined
  return {
    ...node,
    ...(level ? { attrs: { ...node.attrs, level } } : {}),
    ...(node.content ? { content: node.content.map((child) => clampHeadings(child, min, max)) } : {}),
  }
}

export const MarkdownPaste = Extension.create({
  name: 'markdownPaste',

  addProseMirrorPlugins() {
    const editor = this.editor
    return [
      new Plugin({
        key: new PluginKey('markdownPaste'),
        props: {
          handlePaste: (view, event) => {
            const text = event.clipboardData?.getData('text/plain') ?? ''
            const html = event.clipboardData?.getData('text/html') ?? ''
            if (!editor.markdown || !text.trim() || !looksLikeMarkdown(text, html)) return false
            if (view.state.selection.$from.parent.type.spec.code) return false
            const doc = clampHeadings(editor.markdown.parse(text), 2, 4)
            return editor.commands.insertContent(doc.content ?? [])
          },
        },
      }),
    ]
  },
})
