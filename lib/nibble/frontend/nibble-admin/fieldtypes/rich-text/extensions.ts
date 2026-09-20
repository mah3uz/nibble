import { Node, mergeAttributes } from '@tiptap/core'
import { CodeBlockLowlight } from '@tiptap/extension-code-block-lowlight'
import Image from '@tiptap/extension-image'
import { ListItem } from '@tiptap/extension-list'
import { Table, TableCell, TableHeader, TableRow } from '@tiptap/extension-table'
import StarterKit from '@tiptap/starter-kit'
import { VueNodeViewRenderer } from '@tiptap/vue-3'
import { common, createLowlight } from 'lowlight'
import type { Component } from 'vue'

const lowlight = createLowlight(common)

export const codeLanguages = lowlight.listLanguages().sort()
export const RichTextCodeBlock = CodeBlockLowlight.configure({ lowlight })

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
    heading: { levels: [2, 3, 4] },
    listItem: false,
    link: { openOnClick: false, autolink: true, defaultProtocol: 'https' },
  }),
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
