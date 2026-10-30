import { createSSRApp } from 'vue'
import { renderToString } from 'vue/server-renderer'
import { describe, expect, it, vi } from 'vitest'
import Cta from '../views/sets/cta.vue'
import Embed from '../views/sets/embed.vue'
import { embedSrc } from '../lib/embed'

vi.mock('@inertiajs/vue3', async () => {
  const { defineComponent, h } = await import('vue')
  return {
    Link: defineComponent({
      props: { href: { type: String, default: '' } },
      setup:
        (props, { slots }) =>
        () =>
          h('a', { href: props.href, 'data-inertia': '' }, slots.default?.()),
    }),
  }
})

const render = (component: object, props: Record<string, unknown>) => renderToString(createSSRApp(component, props))

describe('embedSrc', () => {
  it.each([
    ['https://www.youtube.com/watch?v=dQw4w9WgXcQ', 'https://www.youtube-nocookie.com/embed/dQw4w9WgXcQ'],
    ['https://youtu.be/dQw4w9WgXcQ', 'https://www.youtube-nocookie.com/embed/dQw4w9WgXcQ'],
    ['https://vimeo.com/76979871', 'https://player.vimeo.com/video/76979871?dnt=1'],
  ])('turns %s into a privacy-friendly player', (url, expected) => {
    expect(embedSrc(url)).toBe(expected)
  })

  it.each([
    'http://www.youtube.com/watch?v=dQw4w9WgXcQ',
    'https://youtube.com.evil.example/watch?v=dQw4w9WgXcQ',
    'https://www.youtube.com/watch?v="><script>',
    'javascript:alert(1)',
    'https://example.com/video',
    '/about',
  ])('refuses %s', (url) => {
    expect(embedSrc(url)).toBeNull()
  })
})

describe('embed set', () => {
  it('draws a lazy, titled iframe for a video', async () => {
    const html = await render(Embed, { url: 'https://youtu.be/dQw4w9WgXcQ', caption: 'The talk' })
    expect(html).toContain('<iframe')
    expect(html).toContain('loading="lazy"')
    expect(html).toContain('title="The talk"')
    expect(html).toContain('youtube-nocookie.com/embed/dQw4w9WgXcQ')
  })

  it('links to anything else, and never to a script address', async () => {
    expect(await render(Embed, { url: 'https://example.com/page' })).toContain('<a href="https://example.com/page"')
    expect(await render(Embed, { url: 'javascript:alert(1)' })).not.toContain('javascript:')
  })
})

describe('cta set', () => {
  const base = { heading: 'Join', button_label: 'Go' }

  it('uses the router for an on-site link', async () => {
    const html = await render(Cta, { ...base, link: { type: 'entry', url: '/about', id: 1 } })
    expect(html).toContain('data-inertia')
  })

  it('uses a plain anchor for an off-site link', async () => {
    const html = await render(Cta, { ...base, link: { type: 'url', url: 'https://example.com' } })
    expect(html).toContain('href="https://example.com"')
    expect(html).not.toContain('data-inertia')
  })
})
