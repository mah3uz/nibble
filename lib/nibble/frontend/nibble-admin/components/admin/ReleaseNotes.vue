<script setup lang="ts">
defineProps<{ source: string }>()
</script>

<template>
  <!-- eslint-disable-next-line vue/no-v-html -- Nibble's own notes, rendered from the CHANGELOG we publish. -->
  <div class="prose prose-sm max-w-none dark:prose-invert [&_.anchor]:hidden" v-html="source" />
</template>
