<script setup lang="ts">
defineProps<{ heading: string; text?: string | null; button_label?: string | null; link?: { url: string } | null }>()
</script>

<template>
  <aside class="not-prose my-12 border-y border-current/20 py-10">
    <h2 class="font-display text-4xl uppercase">{{ heading }}</h2>
    <p v-if="text" class="mt-4 max-w-[48ch] text-lg text-gray-600 dark:text-gray-300">{{ text }}</p>
    <a
      v-if="button_label && link"
      :href="link.url"
      class="bg-ink dark:text-ink mt-6 inline-flex min-h-12 items-center gap-4 rounded-sm px-4 py-3 text-white dark:bg-gray-100"
    >
      {{ button_label }} <span aria-hidden="true">↗</span>
    </a>
  </aside>
</template>
