<script setup lang="ts">
import { computed } from 'vue'

const icons = Object.fromEntries(
  Object.entries(
    import.meta.glob<string>('@/assets/icons/admin/*.svg', { query: '?raw', import: 'default', eager: true }),
  ).map(([path, svg]) => [path.split('/').pop()!.replace('.svg', ''), svg]),
)

const props = defineProps<{ name: string }>()
const svg = computed(() => icons[props.name] ?? '')
</script>

<template>
  <!-- eslint-disable-next-line vue/no-v-html -->
  <span class="inline-flex shrink-0 [&>svg]:size-full" aria-hidden="true" v-html="svg" />
</template>
