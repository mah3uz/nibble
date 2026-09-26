import { describe, expect, it } from 'vitest'
import { codeLanguages, lowlight } from '../highlight'

type Node = { type: string; value?: string; properties?: { className?: string[] }; children?: Node[] }

function tokens(language: string, source: string) {
  const found: Record<string, string[]> = {}
  const walk = (node: Node) => {
    const [name] = node.properties?.className ?? []
    if (name) (found[name] ??= []).push((node.children ?? []).map((child) => child.value ?? '').join(''))
    node.children?.forEach(walk)
  }
  walk(lowlight.highlight(language, source) as Node)
  return found
}

describe('code highlighting', () => {
  it('offers Vue and ERB, which a Nibble site writes its views and templates in', () => {
    expect(codeLanguages).toContain('vue')
    expect(codeLanguages).toContain('erb')
  })

  it('reads each part of a single-file component in its own language', () => {
    const found = tokens(
      'vue',
      [
        '<script setup lang="ts">',
        'const title: string = "Hello"',
        '</script>',
        '',
        '<template>',
        '  <h1 class="title">{{ title }}</h1>',
        '</template>',
        '',
        '<style>',
        '.title { color: red; }',
        '</style>',
      ].join('\n'),
    )

    expect(found['hljs-name']).toEqual(expect.arrayContaining(['script', 'template', 'h1', 'style']))
    expect(found['hljs-built_in']).toContain('string')
    expect(found['hljs-selector-class']).toContain('.title')
  })

  it('reads ERB as HTML with Ruby inside the tags', () => {
    const found = tokens('erb', '<p><%= link_to "Home", root_path if signed_in? %></p>')

    expect(found['hljs-name']).toContain('p')
    expect(found['hljs-keyword']).toContain('if')
  })
})
