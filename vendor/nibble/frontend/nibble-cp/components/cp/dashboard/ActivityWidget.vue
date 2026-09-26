<script setup lang="ts">
import { Link } from '@inertiajs/vue3'
import { initials, timeAgo } from '@/lib/format'
import type { ActivityData } from './types'

defineProps<{ data: ActivityData }>()
</script>

<template>
  <ul v-if="data.items.length">
    <li
      v-for="(item, index) in data.items"
      :key="index"
      class="flex items-start gap-3 border-b border-gray-100 px-4.5 py-2.5 last:border-0 dark:border-gray-800"
    >
      <span
        class="grid size-7 shrink-0 place-items-center rounded-full bg-gray-100 text-[11px] font-medium text-gray-600 dark:bg-gray-800 dark:text-gray-300"
        aria-hidden="true"
        >{{ initials(item.author) }}</span
      >
      <p class="min-w-0 flex-1 pt-1 text-sm text-gray-700 dark:text-gray-300">
        <span class="font-medium text-gray-900 dark:text-white">{{ item.author ?? 'Someone' }}</span>
        {{ item.verb }}
        <Link v-if="item.url" :href="item.url" class="font-medium text-gray-900 hover:underline dark:text-white">{{
          item.title
        }}</Link>
        <template v-else>{{ item.title }}</template>
        <span v-if="item.after" class="ms-1">{{ item.after }}</span>
      </p>
      <time :datetime="item.created_at" class="shrink-0 pt-1 text-xs text-gray-500">{{
        timeAgo(item.created_at)
      }}</time>
    </li>
  </ul>
  <p v-else class="px-4.5 py-8 text-center text-sm text-gray-500">No content changes yet.</p>
</template>
