<script setup lang="ts">
import { nextTick, onMounted, watch } from 'vue'
import { RichText } from '@nibble'
import type { RichTextValue } from '@nibble'

const props = defineProps<{ value: RichTextValue }>()

// Prism's language files are IIFEs that reach for a global Prism, so they can only be loaded in a browser.
let prism: Promise<{ highlightAll: () => void }> | null = null

function load() {
  prism ??= (async () => {
    const core = await import('prismjs')
    await Promise.all([
      import('prismjs/components/prism-bash'),
      import('prismjs/components/prism-json'),
      import('prismjs/components/prism-ruby'),
      import('prismjs/components/prism-yaml'),
    ])
    return core.default
  })()

  return prism
}

// Nibble renders code blocks as <code class="language-x"> and leaves them alone; highlighting is the theme's.
async function highlight() {
  if (typeof window === 'undefined') return

  const Prism = await load()
  await nextTick()
  Prism.highlightAll()
}

onMounted(highlight)
watch(() => props.value, highlight)
</script>

<template>
  <RichText :value="value" />
</template>
