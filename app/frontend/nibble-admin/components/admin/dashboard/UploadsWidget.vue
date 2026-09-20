<script setup lang="ts">
import { Link } from '@inertiajs/vue3'
import { timeAgo } from '@/lib/format'
import type { UploadsData } from './types'

defineProps<{ data: UploadsData }>()
</script>

<template>
  <ul v-if="data.items.length" class="grid grid-cols-3 gap-2 p-3 sm:grid-cols-4">
    <li v-for="item in data.items" :key="item.id">
      <Link :href="item.url" class="group block" :title="`${item.title} · ${timeAgo(item.created_at)}`">
        <span
          class="grid aspect-square place-items-center overflow-hidden rounded-lg border border-gray-100 bg-gray-50 dark:border-gray-800 dark:bg-gray-900"
        >
          <img
            v-if="item.thumbnail"
            :src="item.thumbnail"
            :alt="item.title"
            loading="lazy"
            class="size-full object-cover transition-transform duration-300 group-hover:scale-105"
          />
          <span v-else class="text-xs font-medium text-gray-500 uppercase">{{ item.extension }}</span>
        </span>
        <span class="mt-1 block truncate text-xs text-gray-600 dark:text-gray-400">{{ item.title }}</span>
      </Link>
    </li>
  </ul>
  <p v-else class="px-4.5 py-8 text-center text-sm text-gray-500">Nothing uploaded yet.</p>
</template>
