import { Extension } from '@tiptap/core'

export type GlobalLinkField = { handle: string; display: string; address: string }
export type GlobalLinkSet = { handle: string; title: string; fields: GlobalLinkField[] }
export type GlobalLinkChoice = { set: string; field: string }

const REF = /^global:([a-z0-9][a-z0-9_-]*)\.([a-z][a-z0-9_]*)$/

export const GlobalLinkRef = Extension.create({
  name: 'globalLinkRef',
  addGlobalAttributes: () => [
    {
      types: ['link'],
      attributes: {
        ref: {
          default: null,
          parseHTML: (element) => element.getAttribute('data-ref'),
          renderHTML: (attributes) => (attributes.ref ? { 'data-ref': attributes.ref } : {}),
        },
      },
    },
  ],
})

export function parseGlobalRef(ref: unknown): GlobalLinkChoice | null {
  const match = typeof ref === 'string' ? REF.exec(ref) : null
  return match ? { set: match[1]!, field: match[2]! } : null
}

export function findGlobalField(sets: GlobalLinkSet[], choice: GlobalLinkChoice) {
  return sets.find((set) => set.handle === choice.set)?.fields.find((field) => field.handle === choice.field) ?? null
}

export type LinkDialog = {
  mode: 'url' | 'global'
  href: string
  choice: GlobalLinkChoice
  newWindow: boolean
}

// null removes the link. A global link carries the address it has now, so the stored href is never stale on save.
export function linkAttributes(dialog: LinkDialog, sets: GlobalLinkSet[]) {
  const target = dialog.newWindow ? '_blank' : null
  if (dialog.mode === 'url') return dialog.href ? { href: dialog.href, ref: null, target } : null

  const field = findGlobalField(sets, dialog.choice)
  return field ? { href: field.address, ref: `global:${dialog.choice.set}.${dialog.choice.field}`, target } : null
}

export async function fetchGlobalLinks(): Promise<GlobalLinkSet[]> {
  const response = await fetch('/cp/link_suggestions/globals', { headers: { Accept: 'application/json' } })
  return response.ok ? (await response.json()).globals : []
}
