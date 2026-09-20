export type NavLink = { type: 'url'; url: string } | { type: 'entry' | 'term'; id: number }
export type NavTreeItem = {
  id: string
  title: string
  link: NavLink
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
