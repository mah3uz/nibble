<script setup lang="ts">
import { nextTick, onMounted, useTemplateRef, watch } from 'vue'
import { RichText } from '@nibble'
import type { RichTextValue } from '@nibble'

const props = defineProps<{ value: RichTextValue }>()
const root = useTemplateRef<HTMLElement>('root')

const LANGUAGES = {
  arduino: () => import('highlight.js/lib/languages/arduino'),
  bash: () => import('highlight.js/lib/languages/bash'),
  c: () => import('highlight.js/lib/languages/c'),
  cpp: () => import('highlight.js/lib/languages/cpp'),
  csharp: () => import('highlight.js/lib/languages/csharp'),
  css: () => import('highlight.js/lib/languages/css'),
  diff: () => import('highlight.js/lib/languages/diff'),
  go: () => import('highlight.js/lib/languages/go'),
  graphql: () => import('highlight.js/lib/languages/graphql'),
  ini: () => import('highlight.js/lib/languages/ini'),
  java: () => import('highlight.js/lib/languages/java'),
  javascript: () => import('highlight.js/lib/languages/javascript'),
  json: () => import('highlight.js/lib/languages/json'),
  kotlin: () => import('highlight.js/lib/languages/kotlin'),
  less: () => import('highlight.js/lib/languages/less'),
  lua: () => import('highlight.js/lib/languages/lua'),
  makefile: () => import('highlight.js/lib/languages/makefile'),
  markdown: () => import('highlight.js/lib/languages/markdown'),
  objectivec: () => import('highlight.js/lib/languages/objectivec'),
  perl: () => import('highlight.js/lib/languages/perl'),
  php: () => import('highlight.js/lib/languages/php'),
  'php-template': () => import('highlight.js/lib/languages/php-template'),
  plaintext: () => import('highlight.js/lib/languages/plaintext'),
  python: () => import('highlight.js/lib/languages/python'),
  'python-repl': () => import('highlight.js/lib/languages/python-repl'),
  r: () => import('highlight.js/lib/languages/r'),
  ruby: () => import('highlight.js/lib/languages/ruby'),
  rust: () => import('highlight.js/lib/languages/rust'),
  scss: () => import('highlight.js/lib/languages/scss'),
  shell: () => import('highlight.js/lib/languages/shell'),
  sql: () => import('highlight.js/lib/languages/sql'),
  swift: () => import('highlight.js/lib/languages/swift'),
  typescript: () => import('highlight.js/lib/languages/typescript'),
  vbnet: () => import('highlight.js/lib/languages/vbnet'),
  wasm: () => import('highlight.js/lib/languages/wasm'),
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
