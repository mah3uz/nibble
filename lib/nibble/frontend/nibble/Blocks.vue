<script setup lang="ts">
import { resolveSet } from '@/lib/resolve-page'
import type { SetBlock } from './types'

defineProps<{ blocks: SetBlock[] | null | undefined }>()
</script>

<template>
  <template v-for="block in blocks ?? []" :key="block.id">
    <component :is="resolveSet(block.type)" v-if="resolveSet(block.type)" v-bind="block" />
  </template>
</template>
