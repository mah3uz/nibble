<script setup lang="ts">
import { computed } from 'vue'
import Blocks from './Blocks.vue'
import type { RichTextValue, SetBlock } from './types'

const props = defineProps<{ value: RichTextValue }>()

type Part = { kind: 'html'; html: string; key: string } | { kind: 'set'; block: SetBlock; key: string }

const parts = computed<Part[]>(() => {
  if (!props.value) return []
  if (typeof props.value === 'string') return [{ kind: 'html', html: props.value, key: 'html' }]
  return props.value.map((part, index) =>
    part.type === 'text'
      ? { kind: 'html', html: String(part.text), key: `text-${index}` }
      : { kind: 'set', block: part as SetBlock, key: String((part as SetBlock).id) },
  )
})
</script>

<template>
  <template v-for="part in parts" :key="part.key">
    <div v-if="part.kind === 'html'" v-html="part.html" />
    <Blocks v-else :blocks="[part.block]" />
  </template>
</template>
