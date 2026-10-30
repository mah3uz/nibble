import { describe, expect, expectTypeOf, it } from 'vitest'
import type { useNavigation } from '../composables'
import type { Link, NavigationItem, NavigationItemBase, NavigationLinkType } from '../types'

type LinkOnlyNavigationItem = NavigationItemBase<LinkOnlyNavigationItem> & {
  kind: 'link'
  type: NavigationLinkType
  url: string
  fields: {}
  entry: null
}

type FixtureNavigationEntry = { summary: string | null }
type FixtureNavigationItem =
  | (NavigationItemBase<FixtureNavigationItem> & {
      kind: 'link' | 'heading'
      fields: { icon: string | null }
      entry: FixtureNavigationEntry | null
    })
  | (NavigationItemBase<FixtureNavigationItem> & {
      kind: 'featured'
      fields: { icon: string | null; badge: string }
      entry: FixtureNavigationEntry | null
    })

declare module '../types' {
  interface NavigationMenus {
    fixture: FixtureNavigationItem
  }
}

type Items<H extends string> = ReturnType<typeof useNavigation<H>>['value']

describe('typed navigation', () => {
  it('lets a theme read an item field its menu declares, and not one it does not', () => {
    const item = { kind: 'link', fields: { icon: null }, entry: null } as unknown as Items<'fixture'>[number]

    expectTypeOf(item.fields.icon).toEqualTypeOf<string | null>()
    expectTypeOf(item.entry).toEqualTypeOf<FixtureNavigationEntry | null>()
    // @ts-expect-error colour is not an item field of this menu
    expect(item.fields.colour).toBeUndefined()
  })

  it('narrows on kind to the fields only that kind has', () => {
    const read = (item: Items<'fixture'>[number]) => (item.kind === 'featured' ? item.fields.badge : item.fields.icon)

    expect(read({ kind: 'featured', fields: { icon: null, badge: 'New' } } as Items<'fixture'>[number])).toBe('New')
  })

  it('keeps a link-only menu assignable to Link, so themes that typed their menu with it still compile', () => {
    const items: LinkOnlyNavigationItem[] = []
    const links: Link[] = items

    expect(links).toEqual([])
  })

  it('types a menu the schema does not name loosely', () => {
    expectTypeOf({} as Items<'unlisted'>[number]).toEqualTypeOf<NavigationItem>()
  })
})
