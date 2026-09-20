<script setup lang="ts">
import { ref, watch } from 'vue'
import type { AssetRow } from './api'
import AssetSelector from './AssetSelector.vue'

const open = ref(false)
let resolver: ((row: AssetRow | null) => void) | null = null

function finish(row: AssetRow | null) {
  resolver?.(row)
  resolver = null
}

function pick(): Promise<AssetRow | null> {
  finish(null)
  open.value = true
  return new Promise((resolve) => (resolver = resolve))
}

watch(open, (isOpen) => !isOpen && setTimeout(() => finish(null)))

defineExpose({ pick })
</script>

<template>
  <AssetSelector v-model:open="open" :max-files="1" @select="([row]) => finish(row ?? null)" />
</template>
