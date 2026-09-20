<script setup lang="ts">
defineProps<{ title: string | null; eyebrow?: string | null; description?: string | null }>()
</script>

<template>
  <header class="mb-12">
    <p v-if="eyebrow" class="mb-5 font-mono text-base text-accent sm:text-sm">{{ eyebrow }}</p>
    <h1 class="font-display max-w-[20ch] text-6xl text-balance uppercase sm:text-7xl">{{ title }}</h1>
    <p v-if="description" class="mt-6 max-w-[48ch] text-lg leading-8 text-gray-600 dark:text-gray-300">
      {{ description }}
    </p>
  </header>
</template>
