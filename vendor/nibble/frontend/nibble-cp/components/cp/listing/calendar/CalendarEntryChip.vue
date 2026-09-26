<script setup lang="ts">
import { Link } from '@inertiajs/vue3'
import type { CalendarEntry } from './types'

defineProps<{ entry: CalendarEntry }>()

const TONE: Record<string, string> = {
  published: 'border-green-500 bg-green-50 dark:bg-green-900/20',
  draft: 'border-gray-300 bg-gray-50 dark:bg-gray-800',
  scheduled: 'border-purple-500 bg-purple-50 dark:bg-purple-900/20',
}
</script>

<template>
  <Link
    :href="entry.edit_url"
    class="mb-1 block cursor-pointer rounded-r border-l-2 p-1 text-xs hover:shadow-sm"
    :class="TONE[entry.status] ?? TONE.draft"
  >
    <div class="line-clamp-2 font-medium">{{ entry.title ?? 'Untitled' }}</div>
  </Link>
</template>
