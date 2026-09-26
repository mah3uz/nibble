import { afterEach, describe, expect, test, vi } from 'vitest'
import { getRecentVisits, labelForVisit, recordVisit, removeRecentVisit } from '../recentVisits'
import type { NavSection } from '../cp'

function fakeSessionStorage() {
  const store = new Map<string, string>()
  return {
    getItem: (key: string) => store.get(key) ?? null,
    setItem: (key: string, value: string) => void store.set(key, value),
  } as Storage
}

afterEach(() => {
  vi.unstubAllGlobals()
})

describe('recordVisit / getRecentVisits', () => {
  test('records visits most-recent-first, deduplicating by url', () => {
    vi.stubGlobal('sessionStorage', fakeSessionStorage())

    recordVisit('/cp/posts', 'Posts')
    recordVisit('/cp/pages', 'Pages')
    recordVisit('/cp/posts', 'Posts (revisited)')

    expect(getRecentVisits()).toEqual([
      { url: '/cp/posts', label: 'Posts (revisited)' },
      { url: '/cp/pages', label: 'Pages' },
    ])
  })

  test('caps at 5 entries like Statamic’s palette, dropping the oldest', () => {
    vi.stubGlobal('sessionStorage', fakeSessionStorage())

    for (let i = 0; i < 7; i++) recordVisit(`/cp/item-${i}`, `Item ${i}`)

    const urls = getRecentVisits().map((visit) => visit.url)
    expect(urls).toHaveLength(5)
    expect(urls[0]).toBe('/cp/item-6')
    expect(urls).not.toContain('/cp/item-0')
    expect(urls).not.toContain('/cp/item-1')
  })

  test('removing a recent visit drops only that url, so the palette forgets exactly the entry the user dismissed', () => {
    vi.stubGlobal('sessionStorage', fakeSessionStorage())

    recordVisit('/cp/posts', 'Posts')
    recordVisit('/cp/pages', 'Pages')
    removeRecentVisit('/cp/posts')

    expect(getRecentVisits()).toEqual([{ url: '/cp/pages', label: 'Pages' }])
  })

  test('without sessionStorage (this module runs without a DOM), reads and writes are no-ops rather than throwing', () => {
    vi.stubGlobal('sessionStorage', undefined)
    expect(() => recordVisit('/cp/posts', 'Posts')).not.toThrow()
    expect(getRecentVisits()).toEqual([])
  })
})

describe('labelForVisit', () => {
  const nav: NavSection[] = [
    {
      handle: 'content',
      label: 'Content',
      items: [
        {
          title: 'Posts',
          url: '/cp/posts',
          icon: 'posts',
          active: '/cp/posts',
          children: [
            {
              title: 'Categories',
              url: '/cp/categories',
              icon: 'categories',
              active: '/cp/categories',
              children: null,
              badge: null,
              badge_tone: null,
            },
          ],
          badge: null,
          badge_tone: null,
        },
      ],
    },
  ]

  test("prefers the page's own last breadcrumb — the record's real title, not just its section", () => {
    expect(
      labelForVisit('/cp/posts/42/edit', [{ label: 'Posts', url: '/cp/posts' }, { label: 'A real title' }], nav),
    ).toBe('A real title')
  })

  test('falls back to the longest-matching nav item, including children', () => {
    expect(labelForVisit('/cp/posts/42/edit', [], nav)).toBe('Posts')
    expect(labelForVisit('/cp/categories', [], nav)).toBe('Categories')
  })

  test('falls back to a cleaned-up path when nothing matches', () => {
    expect(labelForVisit('/cp/unknown-page', [], nav)).toBe('unknown page')
  })

  test('the dashboard root falls back to "Dashboard"', () => {
    expect(labelForVisit('/cp', [], nav)).toBe('Dashboard')
  })
})
