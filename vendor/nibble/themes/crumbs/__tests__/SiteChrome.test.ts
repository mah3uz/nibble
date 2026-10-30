import { createSSRApp, h, type Component } from 'vue'
import { renderToString } from 'vue/server-renderer'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import type { NavigationItem } from '@nibble'
import { onSite } from '../lib/links'
import SiteFooter from '../components/SiteFooter.vue'
import SiteHeader from '../components/SiteHeader.vue'
import Pager from '../components/Pager.vue'

const state = vi.hoisted(() => ({
  mounted: false,
  url: '/',
  site: {} as Record<string, unknown>,
  navigation: {} as Record<string, unknown[]>,
}))

vi.mock('vue', async (original) => ({
  ...(await original<typeof import('vue')>()),
  onMounted: (fn: () => void) => state.mounted && fn(),
}))
vi.mock('@inertiajs/vue3', async () => {
  const { defineComponent, h } = await import('vue')
  return {
    usePage: () => ({ url: state.url }),
    Link: defineComponent({
      props: { href: { type: String, required: true } },
      setup:
        (props, { slots }) =>
        () =>
          h('a', { href: props.href, 'data-inertia': '' }, slots.default?.()),
    }),
  }
})
vi.mock('@nibble', async () => {
  const { computed } = await import('vue')
  return {
    useGlobals: () => computed(() => state.site),
    useNavigation: (handle: string) => computed(() => state.navigation[handle] ?? []),
    Image: (await import('../../../frontend/nibble/Image.vue')).default,
    Pagination: (await import('../../../frontend/nibble/Pagination.vue')).default,
  }
})

const item = (
  title: string,
  url: string,
  children: NavigationItem[] = [],
  state: Partial<NavigationItem> = {},
): NavigationItem => ({
  kind: 'link',
  type: 'url',
  title,
  url,
  new_tab: false,
  current: false,
  in_trail: false,
  fields: {},
  entry: null,
  children,
  ...state,
})
const heading = (title: string, children: NavigationItem[]) =>
  item(title, '', children, { kind: 'heading', type: null, url: null })
const render = (component: Component, props = {}) => renderToString(createSSRApp({ render: () => h(component, props) }))
const anchor = (html: string, text: string) =>
  html.match(new RegExp(`<a[^>]*>\\s*${text}\\s*(<!--v-if-->)?</a>`))?.[0] ?? ''

beforeEach(() => {
  state.mounted = false
  state.url = '/'
  state.site = { name: 'Crumbs' }
  state.navigation = { main: [item('Archive', '/blog'), item('About', '/about')] }
})
afterEach(() => vi.unstubAllGlobals())

describe('onSite', () => {
  it('keeps only paths on this site, so another origin is never fetched as an Inertia visit', () => {
    expect(onSite('/topics')).toBe(true)
    expect(onSite('/')).toBe(true)
    expect(onSite('https://github.com/example')).toBe(false)
    expect(onSite('//evil.example')).toBe(false)
    expect(onSite('/\\evil.example')).toBe(false)
    expect(onSite('mailto:hello@example.com')).toBe(false)
  })
})

describe('crumbs SiteHeader', () => {
  it('draws an off-site menu item as a plain link, because an Inertia visit to another origin does nothing', async () => {
    state.navigation.main = [item('Topics', '/topics'), item('GitHub', 'https://github.com/example')]
    const html = await render(SiteHeader)

    expect(anchor(html, 'Topics')).toContain('data-inertia')
    expect(anchor(html, 'GitHub')).toContain('href="https://github.com/example"')
    expect(anchor(html, 'GitHub')).not.toContain('data-inertia')
  })

  it('draws a nested item’s children in both menus, so nothing an editor nests in Main disappears', async () => {
    state.navigation.main = [
      item(
        'Archive',
        '/blog',
        [item('First', '/blog/first', [], { current: true, in_trail: true }), item('Elsewhere', 'https://x.test')],
        { in_trail: true },
      ),
    ]
    const html = await render(SiteHeader)

    const desktop = html.match(/<nav aria-label="Main navigation"[\s\S]*?<\/nav>/)![0]
    expect(desktop).toMatch(/<details[^>]*name="main-menu"/)
    expect(desktop).toMatch(/<summary[^>]*>\s*Archive/)
    expect(anchor(desktop, 'Archive')).toContain('aria-current="true"')
    expect(anchor(desktop, 'First')).toContain('aria-current="page"')
    expect(anchor(desktop, 'Elsewhere')).not.toContain('data-inertia')

    const mobile = html.match(/<nav[^>]*id="mobile-navigation"[\s\S]*?<\/nav>/)![0]
    expect(anchor(mobile, 'First')).toContain('aria-current="page"')
    expect(anchor(mobile, 'Elsewhere')).toContain('href="https://x.test"')
  })

  it('marks the current page and its section from what the server says, not by matching the address itself', async () => {
    state.url = '/about'
    state.navigation.main = [
      item('About', '/about'),
      item('Archive', '/blog', [], { in_trail: true }),
      item('Reading', '/topics/reading', [], { current: true, in_trail: true }),
    ]
    const desktop = (await render(SiteHeader)).match(/<nav aria-label="Main navigation"[\s\S]*?<\/nav>/)![0]

    expect(anchor(desktop, 'About')).not.toContain('aria-current')
    expect(anchor(desktop, 'Archive')).toContain('aria-current="true"')
    expect(anchor(desktop, 'Archive')).toContain('underline')
    expect(anchor(desktop, 'Reading')).toContain('aria-current="page"')
  })

  it('opens a new-tab item in a new tab, and says so to people who can’t see it', async () => {
    state.navigation.main = [item('Shop', 'https://shop.example', [], { new_tab: true }), item('About', '/about')]
    const html = await render(SiteHeader)

    const shop = html.match(/<a[^>]*href="https:\/\/shop.example"[^>]*>[\s\S]*?<\/a>/)![0]
    expect(shop).toContain('target="_blank"')
    expect(shop).toContain('rel="noopener"')
    expect(shop).toMatch(/Shop<span class="sr-only"> \(opens in a new tab\)<\/span>/)
    expect(anchor(html, 'About')).not.toContain('target')
  })

  it('draws a heading in a dropdown as a label, not a link, so a menu with headings still renders', async () => {
    state.navigation.main = [heading('Company', [heading('People', []), item('Jobs', '/jobs')])]
    const html = await render(SiteHeader)
    const desktop = html.match(/<nav aria-label="Main navigation"[\s\S]*?<\/nav>/)![0]

    expect(desktop).toMatch(/<summary[^>]*>\s*Company/)
    expect(desktop).toMatch(/<p[^>]*>\s*People\s*<\/p>/)
    expect(desktop).not.toMatch(/<a[^>]*>\s*(Company|People)/)
    expect(anchor(desktop, 'Jobs')).toContain('href="/jobs"')
  })

  it('names the home link by the visible site name, and shows the logo in its place when one is set', async () => {
    expect(anchor(await render(SiteHeader), 'Crumbs')).not.toContain('aria-label')

    state.site = { name: 'Crumbs', logo: { url: '/media/logo.svg', alt: 'Our logo' } }
    const home = (await render(SiteHeader)).match(/<a[^>]*href="\/"[\s\S]*?<\/a>/)![0]
    expect(home).toMatch(/<img src="\/media\/logo.svg" alt(="")? /)
    expect(home).toContain('<span class="sr-only">Crumbs</span>')
  })

  it('makes search a link to the search page until the page is interactive, then a button that opens the form', async () => {
    const server = await render(SiteHeader)
    expect(server).toMatch(/<a href="\/search" aria-label="Search the site"/)
    expect(server).not.toMatch(/<a[^>]*aria-expanded/)

    state.mounted = true
    vi.stubGlobal('document', { addEventListener: () => {}, documentElement: { dataset: { theme: 'light' } } })
    vi.stubGlobal('localStorage', { getItem: () => null })
    const browser = await render(SiteHeader)
    expect(browser).toMatch(
      /<button type="button" aria-expanded="false" aria-controls="header-search" aria-label="Search the site"/,
    )
  })
})

describe('crumbs SiteFooter', () => {
  it('draws the Footer menu, falling back to Main while the Footer menu is empty', async () => {
    expect(anchor(await render(SiteFooter), 'Archive')).toContain('href="/blog"')

    state.navigation.footer = [item('Privacy', '/privacy'), item('Status', 'https://status.example')]
    const html = await render(SiteFooter)
    expect(html).not.toContain('Archive')
    expect(anchor(html, 'Privacy')).toContain('data-inertia')
    expect(anchor(html, 'Status')).not.toContain('data-inertia')
  })

  it('draws a heading as a column title with its links beneath, and a flat menu as one row of links', async () => {
    state.navigation.footer = [
      heading('Company', [item('About', '/about'), item('Jobs', 'https://jobs.example', [], { new_tab: true })]),
      heading('Help', [item('Contact', '/contact')]),
    ]
    const columns = (await render(SiteFooter)).replace(/<!--.*?-->/g, '').match(/<nav[\s\S]*?<\/nav>/)![0]
    expect([...columns.matchAll(/<h2[^>]*>([^<]*)<\/h2>/g)].map((match) => match[1].trim())).toEqual([
      'Company',
      'Help',
    ])
    expect(columns).toMatch(/Company<\/h2>\s*<ul role="list"><li><a[^>]*href="\/about"/)
    expect(columns).toMatch(/target="_blank" rel="noopener"[^>]*>Jobs<span class="sr-only">/)

    state.navigation.footer = [item('Privacy', '/privacy', [], { current: true, in_trail: true })]
    const flat = (await render(SiteFooter)).replace(/<!--.*?-->/g, '').match(/<nav[\s\S]*?<\/nav>/)![0]
    expect(flat).not.toContain('<h2')
    expect(flat).toMatch(/<nav aria-label="Footer navigation" class="[^"]*gap-x-6[^"]*"><a/)
    expect(anchor(flat, 'Privacy')).toContain('aria-current="page"')
  })

  it('lists the topics the layout queries, linked as site pages, and nothing when there are none', async () => {
    const topics = [{ id: 1, type: 'term' as const, title: 'Slow work', uri: '/topics/slow-work', url: null }]
    const html = await render(SiteFooter, { topics })
    expect(anchor(html, 'Slow work')).toContain('href="/topics/slow-work"')
    expect(anchor(html, 'Slow work')).toContain('data-inertia')
    expect(await render(SiteFooter, { topics: [] })).not.toContain('aria-label="Topics"')
  })

  it('prints no year, which would differ between the server, a cached copy and the browser', async () => {
    expect(await render(SiteFooter)).not.toMatch(/\b20\d\d\b/)
  })
})

describe('crumbs Pager', () => {
  it('names its navigation, so pagers are not all announced as "Pagination"', async () => {
    const meta = { current_page: 1, per_page: 10, total: 30, last_page: 3 }
    expect(await render(Pager, { meta })).toContain('<nav aria-label="Article pages">')
    expect(await render(Pager, { meta, label: 'Search results' })).toContain('<nav aria-label="Search results">')
  })
})
