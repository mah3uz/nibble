import { Extension, Node, mergeAttributes } from '@tiptap/core'
import { CodeBlockLowlight } from '@tiptap/extension-code-block-lowlight'
import Image from '@tiptap/extension-image'
import { ListItem } from '@tiptap/extension-list'
import { Table, TableCell, TableHeader, TableRow } from '@tiptap/extension-table'
import Typography from '@tiptap/extension-typography'
import { CharacterCount, Placeholder } from '@tiptap/extensions'
import StarterKit from '@tiptap/starter-kit'
import { VueNodeViewRenderer } from '@tiptap/vue-3'
import type { Component } from 'vue'
import { lowlight } from '@/lib/highlight'
import { PostHeading } from '@/lib/tiptap/extensions'
import { GlobalLinkRef } from './globalLinks'

export const RichTextCodeBlock = CodeBlockLowlight.configure({ lowlight, enableTabIndentation: true, tabSize: 2 })

export const RichTextImage = Image.extend({
  addAttributes() {
    return {
      ...this.parent?.(),
      width: { default: null },
      height: { default: null },
      asset: {
        default: null,
        parseHTML: (element) => element.getAttribute('data-asset'),
        renderHTML: (attributes) => (attributes.asset ? { 'data-asset': attributes.asset } : {}),
      },
    }
  },
})

// Must match the nodes and marks Nibble::Fieldtypes::RichText renders on the server.
export const baseExtensions = [
  StarterKit.configure({
    codeBlock: false,
    heading: false,
    listItem: false,
    link: { openOnClick: false, autolink: true, defaultProtocol: 'https' },
  }),
  GlobalLinkRef,
  PostHeading,
  RichTextCodeBlock,
  ListItem.extend({ content: '(paragraph | heading) block*' }),
  RichTextImage,
  Table.configure({ resizable: true }),
  TableRow,
  TableHeader,
  TableCell,
]

export function setNode(view: Component) {
  return Node.create({
    name: 'set',
    group: 'block',
    atom: true,
    draggable: true,
    selectable: true,
    addAttributes() {
      return {
        id: { default: null },
        enabled: { default: true },
        values: { default: {} },
      }
    },
    parseHTML: () => [{ tag: 'div[data-nibble-set]' }],
    renderHTML: ({ HTMLAttributes }) => ['div', mergeAttributes(HTMLAttributes, { 'data-nibble-set': '' })],
    addNodeView: () => VueNodeViewRenderer(view),
  })
}

export function hintExtensions(config: Record<string, unknown>) {
  const limit = Number(config.character_limit) || 0
  return [
    Placeholder.configure({ placeholder: typeof config.placeholder === 'string' ? config.placeholder : '' }),
    ...(limit ? [CharacterCount.configure({ limit })] : []),
  ]
}

const InlineHardBreaks = Extension.create({
  name: 'inlineHardBreaks',
  priority: 1000,
  addKeyboardShortcuts() {
    return { Enter: ({ editor }) => editor.commands.setHardBreak() }
  },
})

export function behaviourExtensions(config: Record<string, unknown>) {
  return [
    ...(config.smart_typography === true ? [Typography] : []),
    ...(config.inline === true && config.inline_hard_breaks === true ? [InlineHardBreaks] : []),
  ]
}

export function ruleOptions(config: Record<string, unknown>) {
  return {
    enableInputRules: config.enable_input_rules !== false,
    enablePasteRules: config.enable_paste_rules !== false,
  }
}

export const isFloatingToolbar = (config: Record<string, unknown>) => config.toolbar_mode === 'floating'
