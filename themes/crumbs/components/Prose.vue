<script setup lang="ts">
import { nextTick, onMounted, useTemplateRef, watch } from 'vue'
import { RichText } from '@nibble'
import type { RichTextValue } from '@nibble'

const props = defineProps<{ value: RichTextValue }>()
const root = useTemplateRef<HTMLElement>('root')

const LANGUAGES = {
  bash: () => import('highlight.js/lib/languages/bash'),
  css: () => import('highlight.js/lib/languages/css'),
  go: () => import('highlight.js/lib/languages/go'),
  ini: () => import('highlight.js/lib/languages/ini'),
  javascript: () => import('highlight.js/lib/languages/javascript'),
  json: () => import('highlight.js/lib/languages/json'),
  php: () => import('highlight.js/lib/languages/php'),
  python: () => import('highlight.js/lib/languages/python'),
  ruby: () => import('highlight.js/lib/languages/ruby'),
  rust: () => import('highlight.js/lib/languages/rust'),
  typescript: () => import('highlight.js/lib/languages/typescript'),
  xml: () => import('highlight.js/lib/languages/xml'),
  yaml: () => import('highlight.js/lib/languages/yaml'),
}

type Language = keyof typeof LANGUAGES

const loaded = new Map<Language, Promise<void>>()
let engine: Promise<typeof import('highlight.js/lib/core').default> | null = null

function core() {
  engine ??= import('highlight.js/lib/core').then(({ default: hljs }) => hljs)
  return engine
}

function register(name: Language) {
  if (!loaded.has(name)) {
    const ready = Promise.all([core(), LANGUAGES[name]()]).then(([hljs, grammar]) =>
      hljs.registerLanguage(name, grammar.default),
    )
    loaded.set(name, ready)
  }

  return loaded.get(name)!
}

async function highlight() {
  if (typeof window === 'undefined') return

  await nextTick()
  const blocks = [...(root.value?.querySelectorAll<HTMLElement>('pre code[class*="language-"]') ?? [])]
    .filter((block) => !block.dataset.highlighted)
    .map((block) => ({ block, name: block.className.match(/language-(\S+)/)?.[1] as Language }))
    .filter(({ name }) => name in LANGUAGES)
  if (!blocks.length) return

  const hljs = await core()
  await Promise.all([...new Set(blocks.map(({ name }) => name))].map(register))
  blocks.forEach(({ block }) => hljs.highlightElement(block))
}

onMounted(highlight)
watch(() => props.value, highlight)
</script>

<template>
  <div ref="root"><RichText :value="value" /></div>
</template>
