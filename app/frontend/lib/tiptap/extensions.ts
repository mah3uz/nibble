import Image from '@tiptap/extension-image'
import { Table, TableCell, TableHeader, TableRow } from '@tiptap/extension-table'
import { ListItem } from '@tiptap/extension-list'
import StarterKit from '@tiptap/starter-kit'

// The single Tiptap schema for posts: used by the admin editor and by content import, so imported
// content is exactly what the editor can represent. The server renderer
// (app/services/rich_text/renderer.rb) must handle every node and mark enabled here.

// Images keep their Active Storage blob and intrinsic size so the server can render responsive srcsets.
export const PostImage = Image.extend({
  addAttributes() {
    return {
      ...this.parent?.(),
      width: { default: null },
      height: { default: null },
      blobSignedId: {
        default: null,
        parseHTML: (element) => element.getAttribute('data-blob-signed-id'),
        renderHTML: (attributes) => (attributes.blobSignedId ? { 'data-blob-signed-id': attributes.blobSignedId } : {}),
      },
    }
  },
})

// Imported posts can use `- ## Heading` (a heading as a list item's first line); the default list
// item requires a leading paragraph and would push the heading out of the list.
export const PostListItem = ListItem.extend({ content: '(paragraph | heading) block*' })

export const postExtensions = [
  StarterKit.configure({
    heading: { levels: [2, 3, 4] },
    listItem: false,
    link: { openOnClick: false, autolink: true, defaultProtocol: 'https' },
  }),
  PostListItem,
  PostImage,
  Table,
  TableRow,
  TableHeader,
  TableCell,
]
