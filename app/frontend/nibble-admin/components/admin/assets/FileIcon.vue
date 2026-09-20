<script setup lang="ts">
import { computed } from 'vue'
import { fileIconName } from './fileIcon'

const icons = Object.fromEntries(
  Object.entries(
    import.meta.glob<string>('@/assets/icons/filetypes/*.svg', { query: '?raw', import: 'default', eager: true }),
  ).map(([path, svg]) => [path.split('/').pop()!.replace('.svg', ''), svg]),
)

const props = defineProps<{ extension: string }>()
const svg = computed(() => icons[fileIconName(props.extension)] ?? icons.generic)
</script>

<template>
  <!-- eslint-disable-next-line vue/no-v-html -->
  <span class="inline-flex shrink-0 [&>svg]:size-full" aria-hidden="true" v-html="svg" />
</template>
