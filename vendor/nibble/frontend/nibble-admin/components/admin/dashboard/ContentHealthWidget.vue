<script setup lang="ts">
import { Link } from '@inertiajs/vue3'
import type { ContentHealthData } from './types'

defineProps<{ data: ContentHealthData }>()
</script>

<template>
  <ul>
    <li
      v-for="item in data.items"
      :key="item.label"
      class="border-b border-gray-100 last:border-0 dark:border-gray-800"
    >
      <Link
        :href="item.url"
        class="flex items-center justify-between gap-3 px-4.5 py-2.5 transition-colors hover:bg-gray-50 dark:hover:bg-gray-900/60"
      >
        <span class="truncate text-sm text-gray-800 dark:text-gray-200">{{ item.label }}</span>
        <span
          :class="[
            'shrink-0 rounded-full px-2 py-0.5 text-xs font-medium tabular-nums',
            item.count > 0
              ? 'bg-amber-100 text-amber-800 dark:bg-amber-300/10 dark:text-amber-300'
              : 'bg-gray-100 text-gray-500 dark:bg-gray-800',
          ]"
          >{{ item.count }}</span
        >
      </Link>
    </li>
  </ul>
</template>
