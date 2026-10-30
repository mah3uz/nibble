import type { PublishField } from '@nibble-cp/fieldtypes/types'

export type NavLink =
  { type: 'url'; url: string } | { type: 'entry' | 'term' | 'asset'; id: number } | { type: 'global'; ref: string }
export type NavKind = string
export type NavQuery = {
  collection: string
  parent?: number
  term?: { taxonomy: string; id: number }
  sort?: string
  limit?: number
}
export type NavTreeItem = {
  id: string
  kind: NavKind
  title: string
  link: NavLink | null
  new_tab: boolean
  hidden: boolean
  query?: NavQuery | null
  show_from?: string | null
  show_until?: string | null
  fields: Record<string, unknown>
  field_meta: Record<string, unknown>
  children: NavTreeItem[]
}
export type NavEntry = {
  id: number
  type: 'entry' | 'term'
  group: string
  group_title: string
  title: string
  path: string
  status: 'draft' | 'scheduled' | 'published'
  live: boolean
}
export type NavGlobal = {
  handle: string
  title: string
  fields: { handle: string; display: string; address: string | null }[]
}
export type NavAsset = { id: string; title: string; filename: string; url: string }
export type NavMenu = {
  handle: string
  title: string
  max_depth: number | null
  locale: string
  headings?: boolean
  assets?: boolean
  globals?: NavGlobal[]
  item_fields?: PublishField[]
  kinds?: NavKindDef[]
  queries?: NavQuerySource[]
}
export type NavKindDef = {
  handle: string
  display: string
  link: 'optional' | 'required' | 'none'
  children: boolean
  fields: PublishField[]
}
export type NavQuerySource = {
  handle: string
  title: string
  structured: boolean
  taxonomies: { handle: string; title: string }[]
}
export type NavItemErrors = { messages: string[]; fields: Record<string, string[]> }
