<script setup lang="ts">
import { nextTick, onMounted, useTemplateRef, watch } from 'vue'
import { RichText } from '@nibble'
import type { RichTextValue } from '@nibble'
import { highlight } from '../lib/highlight'

const props = defineProps<{ value: RichTextValue }>()
const root = useTemplateRef<HTMLElement>('root')

async function run() {
  if (typeof window === 'undefined') return

  await nextTick()
  if (!root.value) return

  await highlight(root.value)
}

onMounted(run)
watch(() => props.value, run)
</script>

<template>
  <div ref="root"><RichText :value="value" /></div>
</template>
