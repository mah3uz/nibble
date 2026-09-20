<script setup lang="ts">
defineProps<{ source: string }>()

// prose puts backticks around inline code, and heading anchors are commonmarker's, not ours to show.
const prose =
  'prose prose-sm max-w-none dark:prose-invert [&_.anchor]:hidden [&_code]:before:content-none [&_code]:after:content-none'
</script>

<template>
  <!-- eslint-disable-next-line vue/no-v-html -- Nibble's own notes, rendered from the CHANGELOG we publish. -->
  <div :class="prose" v-html="source" />
</template>
