import { describe, expect, it } from 'vitest'
import { canNest, duplicate, errorsByItem, fits, holdsChildren, move, nest, shift, unnest } from '../tree'
import type { NavKindDef, NavTreeItem } from '../types'

const item = (id: string, children: NavTreeItem[] = []): NavTreeItem => ({
  id,
  kind: 'link',
  title: id.toUpperCase(),
  link: { type: 'url', url: `/${id}` },
  new_tab: false,
  hidden: false,
  fields: {},
  field_meta: {},
  children,
})
const shape = (tree: NavTreeItem[] | null): unknown =>
  tree?.map((node) => (node.children.length ? { [node.id]: shape(node.children) } : node.id))

describe('depth', () => {
  it('lets a two-level menu nest under top-level items only', () => {
    expect(canNest(0, 2)).toBe(true)
    expect(canNest(1, 2)).toBe(false)
  })

  it('nests without limit when the menu sets no max_depth', () => {
    expect(canNest(40, null)).toBe(true)
    expect(fits(item('a', [item('b', [item('c')])]), 40, null)).toBe(true)
  })

  it('counts an item’s children against the limit, so a branch is not dropped deeper than the menu allows', () => {
    const branch = item('a', [item('b')])
    expect(fits(branch, 0, 2)).toBe(true)
    expect(fits(branch, 1, 2)).toBe(false)
  })
})

describe('move', () => {
  const tree = [item('a'), item('b', [item('c')]), item('d')]

  it('moves an item into another list, which is how dragging nests it', () => {
    expect(shape(move(tree, [0], [1], 1, 3))).toEqual([{ b: ['c', 'a'] }, 'd'])
  })

  it('refuses a move that would nest deeper than max_depth', () => {
    expect(move(tree, [1], [0], 0, 2)).toBeNull()
  })

  it('refuses to put an item inside itself', () => {
    expect(move(tree, [1], [1, 0], 0, null)).toBeNull()
  })

  it('leaves the tree it was given alone', () => {
    move(tree, [0], [1], 0, null)
    expect(shape(tree)).toEqual(['a', { b: ['c'] }, 'd'])
  })
})

describe('keyboard moves', () => {
  const tree = [item('a'), item('b', [item('c')]), item('d')]

  it('moves an item up and down among its siblings, and not past either end', () => {
    expect(shape(shift(tree, [0], 1))).toEqual([{ b: ['c'] }, 'a', 'd'])
    expect(shape(shift(tree, [2], -1))).toEqual(['a', 'd', { b: ['c'] }])
    expect(shift(tree, [0], -1)).toBeNull()
    expect(shift(tree, [2], 1)).toBeNull()
  })

  it('moves an item down a level, to the end of the item above it', () => {
    expect(shape(nest(tree, [2], null))).toEqual(['a', { b: ['c', 'd'] }])
  })

  it('cannot move the first item down a level, as nothing is above it', () => {
    expect(nest(tree, [0], null)).toBeNull()
  })

  it('cannot move an item down a level past max_depth', () => {
    expect(nest(tree, [2], 1)).toBeNull()
    expect(nest(tree, [1], 2)).toBeNull()
  })

  it('moves an item up a level, to just after the item it was under', () => {
    expect(shape(unnest(tree, [1, 0]))).toEqual(['a', 'b', 'c', 'd'])
    expect(unnest(tree, [0])).toBeNull()
  })
})

describe('kinds that hold no children', () => {
  const card: NavKindDef = { handle: 'card', display: 'Card', link: 'required', children: false, fields: [] }
  const group: NavKindDef = { handle: 'group', display: 'Group', link: 'none', children: true, fields: [] }
  const as = (kind: string, node: NavTreeItem) => ({ ...node, kind })
  const tree = [as('card', item('a')), as('query', item('q')), as('group', item('g')), item('d')]

  it('refuses to drag an item under a kind the menu says has no children, which the server would refuse', () => {
    expect(holdsChildren(tree[0]!, [card])).toBe(false)
    expect(move(tree, [3], [0], 0, null, [card])).toBeNull()
    expect(nest(tree, [1], null, [card])).toBeNull()
  })

  it('refuses to put anything under a list of pages, whose items come from its collection on the site', () => {
    expect(holdsChildren(tree[1]!)).toBe(false)
    expect(move(tree, [3], [1], 0, null)).toBeNull()
    expect(nest(tree, [2], null)).toBeNull()
  })

  it('still nests under links, headings and kinds that allow children', () => {
    expect(shape(move(tree, [0], [2], 0, null, [card, group]))).toEqual(['q', { g: ['a'] }, 'd'])
    expect(shape(nest(tree, [3], null, [card, group]))).toEqual(['a', 'q', { g: ['d'] }])
  })
})

describe('duplicate', () => {
  it('copies an item and its children just below it, with new ids so the two stay separate', () => {
    let next = 0
    const copied = duplicate([item('a', [item('b')]), item('z')], [0], () => `n${++next}`)!
    expect(shape(copied)).toEqual([{ a: ['b'] }, { n1: ['n2'] }, 'z'])
    expect(copied[1]!.title).toBe('A')
    expect(copied[1]!.children[0]!.link).toEqual({ type: 'url', url: '/b' })
  })
})

describe('errorsByItem', () => {
  it('puts each message on the item it names, and a field’s message on that field too', () => {
    const tree = [item('a'), item('b', [item('c')])]
    const found = errorsByItem(tree, {
      tree: 'The first problem.',
      'tree.1.children.0': '“C” must link to a web page.',
      'tree.0.fields.badge': '“A”: Badge is required.',
    })
    expect(found).toEqual({
      c: { messages: ['“C” must link to a web page.'], fields: {} },
      a: { messages: ['“A”: Badge is required.'], fields: { badge: ['“A”: Badge is required.'] } },
    })
  })
})
