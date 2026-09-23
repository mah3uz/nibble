<script setup lang="ts">
import { Link } from '@inertiajs/vue3'
import { initials, timeAgo } from '@/lib/format'
import type { CommentsData } from './types'

defineProps<{ data: CommentsData }>()
</script>

<template>
  <ul v-if="data.items.length">
    <li v-for="item in data.items" :key="item.id" class="border-b border-gray-100 last:border-0 dark:border-gray-800">
      <Link
        :href="item.url"
        class="flex items-start gap-3 px-4.5 py-2.5 transition-colors hover:bg-gray-50 dark:hover:bg-gray-900/60"
      >
        <span
          class="grid size-7 shrink-0 place-items-center rounded-full bg-gray-100 text-[11px] font-medium text-gray-600 dark:bg-gray-800 dark:text-gray-300"
          aria-hidden="true"
          >{{ initials(item.author) }}</span
        >
        <span class="min-w-0 flex-1">
          <span class="flex items-baseline gap-2 text-sm">
            <span class="font-medium text-gray-900 dark:text-white">{{ item.author ?? 'Someone' }}</span>
            <span class="truncate text-xs text-gray-500">on {{ item.title }}</span>
            <time :datetime="item.created_at" class="ms-auto shrink-0 text-xs text-gray-500">{{
              timeAgo(item.created_at)
            }}</time>
          </span>
          <span
            :class="[
              'mt-0.5 line-clamp-2 block text-sm',
              item.resolved ? 'text-gray-500 line-through' : 'text-gray-700 dark:text-gray-300',
            ]"
            >{{ item.body }}</span
          >
        </span>
      </Link>
    </li>
  </ul>
  <p v-else class="px-4.5 py-8 text-center text-sm text-gray-500">No comments yet.</p>
</template>
