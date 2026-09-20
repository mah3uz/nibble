import { afterEach, describe, expect, test, vi } from 'vitest'
import { getRecentVisits, labelForVisit, recordVisit, removeRecentVisit } from '../recentVisits'
import type { NavSection } from '../admin'

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

    recordVisit('/admin/posts', 'Posts')
    recordVisit('/admin/pages', 'Pages')
    recordVisit('/admin/posts', 'Posts (revisited)')

    expect(getRecentVisits()).toEqual([
      { url: '/admin/posts', label: 'Posts (revisited)' },
      { url: '/admin/pages', label: 'Pages' },
    ])
  })

  test('caps at 5 entries like Statamic’s palette, dropping the oldest', () => {
    vi.stubGlobal('sessionStorage', fakeSessionStorage())

    for (let i = 0; i < 7; i++) recordVisit(`/admin/item-${i}`, `Item ${i}`)

    const urls = getRecentVisits().map((visit) => visit.url)
    expect(urls).toHaveLength(5)
    expect(urls[0]).toBe('/admin/item-6')
    expect(urls).not.toContain('/admin/item-0')
    expect(urls).not.toContain('/admin/item-1')
  })

  test('removing a recent visit drops only that url, so the palette forgets exactly the entry the user dismissed', () => {
    vi.stubGlobal('sessionStorage', fakeSessionStorage())

    recordVisit('/admin/posts', 'Posts')
    recordVisit('/admin/pages', 'Pages')
    removeRecentVisit('/admin/posts')

    expect(getRecentVisits()).toEqual([{ url: '/admin/pages', label: 'Pages' }])
  })

  test('without sessionStorage (this module runs without a DOM), reads and writes are no-ops rather than throwing', () => {
    vi.stubGlobal('sessionStorage', undefined)
    expect(() => recordVisit('/admin/posts', 'Posts')).not.toThrow()
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
          url: '/admin/posts',
          icon: 'posts',
          active: '/admin/posts',
          children: [
            {
              title: 'Categories',
              url: '/admin/categories',
              icon: 'categories',
              active: '/admin/categories',
              children: null,
              badge: null,
            },
          ],
          badge: null,
        },
      ],
    },
  ]

  test("prefers the page's own last breadcrumb — the record's real title, not just its section", () => {
    expect(
      labelForVisit('/admin/posts/42/edit', [{ label: 'Posts', url: '/admin/posts' }, { label: 'A real title' }], nav),
    ).toBe('A real title')
  })

  test('falls back to the longest-matching nav item, including children', () => {
    expect(labelForVisit('/admin/posts/42/edit', [], nav)).toBe('Posts')
    expect(labelForVisit('/admin/categories', [], nav)).toBe('Categories')
  })

  test('falls back to a cleaned-up path when nothing matches', () => {
    expect(labelForVisit('/admin/unknown-page', [], nav)).toBe('unknown page')
  })

  test('the dashboard root falls back to "Dashboard"', () => {
    expect(labelForVisit('/admin', [], nav)).toBe('Dashboard')
  })
})
