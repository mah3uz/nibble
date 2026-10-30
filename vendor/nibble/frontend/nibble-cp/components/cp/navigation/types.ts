import type { PublishField } from '@nibble-cp/fieldtypes/types'

export type NavLink =
  { type: 'url'; url: string } | { type: 'entry' | 'term' | 'asset'; id: number } | { type: 'global'; ref: string }
export type NavKind = 'link' | 'heading'
export type NavTreeItem = {
  id: string
  kind: NavKind
  title: string
  link: NavLink | null
  new_tab: boolean
  hidden: boolean
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
}
export type NavItemErrors = { messages: string[]; fields: Record<string, string[]> }
