<script setup lang="ts">
defineProps<{ source: string }>()

const prose = 'prose prose-sm prose-nibble dark:prose-invert'
</script>

<template>
  <!-- eslint-disable-next-line vue/no-v-html -- Nibble's own notes, rendered from the CHANGELOG we publish. -->
  <div :class="prose" v-html="source" />
</template>
