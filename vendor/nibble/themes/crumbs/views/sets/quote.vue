<script setup lang="ts">
defineProps<{ quote: string; attribution?: string | null }>()
</script>

<template>
  <blockquote>
    <p>{{ quote }}</p>
    <cite v-if="attribution">{{ attribution }}</cite>
  </blockquote>
</template>
