import type { NavItemErrors, NavKindDef, NavTreeItem } from './types'

export type Path = number[]

export const QUERY_SORTS: { value: string; label: string; structured?: boolean }[] = [
  { value: 'title', label: 'By title' },
  { value: 'published_at:desc', label: 'Newest first' },
  { value: 'position', label: 'In the order of the structure', structured: true },
]

// A query item's children come from its collection on the site, so none are added by hand.
export function holdsChildren(item: NavTreeItem, kinds: NavKindDef[] = []): boolean {
  return item.kind !== 'query' && kinds.find((kind) => kind.handle === item.kind)?.children !== false
}

export function levels(item: NavTreeItem): number {
  return 1 + Math.max(0, ...item.children.map(levels))
}

export function canNest(depth: number, maxDepth: number | null): boolean {
  return maxDepth === null || depth + 1 < maxDepth
}

export function fits(item: NavTreeItem, depth: number, maxDepth: number | null): boolean {
  return maxDepth === null || depth + levels(item) <= maxDepth
}

export function itemAt(tree: NavTreeItem[], path: Path): NavTreeItem | undefined {
  let list = tree
  let item: NavTreeItem | undefined
  for (const index of path) {
    item = list[index]
    if (!item) return undefined
    list = item.children
  }
  return item
}

export function pathOf(tree: NavTreeItem[], id: string, parent: Path = []): Path | null {
  for (const [index, item] of tree.entries()) {
    if (item.id === id) return [...parent, index]
    const found = pathOf(item.children, id, [...parent, index])
    if (found) return found
  }
  return null
}

function listAt(tree: NavTreeItem[], parent: Path): NavTreeItem[] | undefined {
  return parent.length === 0 ? tree : itemAt(tree, parent)?.children
}

const copy = (tree: NavTreeItem[]): NavTreeItem[] => JSON.parse(JSON.stringify(tree))

// `index` counts the target list without the moved item, as Sortable reports it.
export function move(
  tree: NavTreeItem[],
  from: Path,
  toParent: Path,
  index: number,
  maxDepth: number | null,
  kinds: NavKindDef[] = [],
): NavTreeItem[] | null {
  if (from.length === 0 || from.every((step, i) => toParent[i] === step)) return null
  const parent = toParent.length ? itemAt(tree, toParent) : undefined
  if (parent && !holdsChildren(parent, kinds)) return null
  const next = copy(tree)
  const source = listAt(next, from.slice(0, -1))
  const target = listAt(next, toParent)
  const item = source?.[from.at(-1)!]
  if (!source || !target || !item || !fits(item, toParent.length, maxDepth)) return null
  source.splice(from.at(-1)!, 1)
  target.splice(Math.min(index, target.length), 0, item)
  return next
}

export function shift(tree: NavTreeItem[], path: Path, delta: -1 | 1): NavTreeItem[] | null {
  const index = path.at(-1)! + delta
  const siblings = listAt(tree, path.slice(0, -1)) ?? []
  if (index < 0 || index >= siblings.length) return null
  return move(tree, path, path.slice(0, -1), index, null)
}

export function nest(
  tree: NavTreeItem[],
  path: Path,
  maxDepth: number | null,
  kinds: NavKindDef[] = [],
): NavTreeItem[] | null {
  const index = path.at(-1)!
  if (index === 0) return null
  const above = [...path.slice(0, -1), index - 1]
  return move(tree, path, above, itemAt(tree, above)!.children.length, maxDepth, kinds)
}

export function unnest(tree: NavTreeItem[], path: Path): NavTreeItem[] | null {
  if (path.length < 2) return null
  const parent = path.slice(0, -1)
  return move(tree, path, parent.slice(0, -1), parent.at(-1)! + 1, null)
}

export function duplicate(
  tree: NavTreeItem[],
  path: Path,
  newId: () => string = () => crypto.randomUUID(),
): NavTreeItem[] | null {
  const next = copy(tree)
  const siblings = listAt(next, path.slice(0, -1))
  const original = siblings?.[path.at(-1)!]
  if (!siblings || !original) return null
  const fresh = (item: NavTreeItem): NavTreeItem => ({ ...item, id: newId(), children: item.children.map(fresh) })
  siblings.splice(path.at(-1)! + 1, 0, fresh(original))
  return next
}

// The server names an item by where it was in the tree it was sent: tree.1.children.0, then .fields.<field> for a field.
export function errorsByItem(
  tree: NavTreeItem[],
  errors: Record<string, string | string[]>,
): Record<string, NavItemErrors> {
  const found: Record<string, NavItemErrors> = {}
  for (const [key, value] of Object.entries(errors)) {
    const message = [value].flat()[0] ?? ''
    const match = key.match(/^tree\.(\d+(?:\.children\.\d+)*)(?:\.fields\.(.+))?$/)
    if (!match) continue
    const item = itemAt(tree, match[1]!.split('.children.').map(Number))
    if (!item) continue
    const entry = (found[item.id] ??= { messages: [], fields: {} })
    entry.messages.push(message)
    if (match[2]) entry.fields[match[2]] = [message]
  }
  return found
}
