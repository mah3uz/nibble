<script setup lang="ts">
import { Link } from '@inertiajs/vue3'
import { computed } from 'vue'
import { onSite } from '../../lib/links'

const props = defineProps<{
  heading: string
  text?: string | null
  button_label?: string | null
  link?: { type: string; url: string; id?: number; title?: string } | null
}>()

const internal = computed(() => !!props.link && onSite(props.link.url))
</script>

<template>
  <aside class="not-prose my-12 border-y border-current/20 py-10">
    <h2 class="font-display text-4xl uppercase">{{ heading }}</h2>
    <p v-if="text" class="mt-4 max-w-[48ch] text-lg text-gray-600 dark:text-gray-300">{{ text }}</p>
    <component
      :is="internal ? Link : 'a'"
      v-if="button_label && link"
      :href="link.url"
      class="bg-ink dark:text-ink mt-6 inline-flex min-h-12 items-center gap-4 rounded-sm px-4 py-3 text-white dark:bg-gray-100"
    >
      {{ button_label }} <span aria-hidden="true">↗</span>
    </component>
  </aside>
</template>
