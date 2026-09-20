<script setup lang="ts">
import { Link } from '@inertiajs/vue3'
import { computed } from 'vue'
import { timeAgo } from '@/lib/format'
import type { MissingPagesData } from './types'

const props = defineProps<{ data: MissingPagesData }>()
const top = computed(() => Math.max(1, ...props.data.items.map((item) => item.hits)))
</script>

<template>
  <ul v-if="data.items.length">
    <li
      v-for="item in data.items"
      :key="item.path"
      class="flex items-center gap-3 border-b border-gray-100 px-4.5 py-2.5 last:border-0 dark:border-gray-800"
    >
      <div class="min-w-0 flex-1">
        <p class="truncate font-mono text-xs text-gray-900 dark:text-white" :title="item.path">{{ item.path }}</p>
        <div class="mt-1.5 flex items-center gap-2">
          <span class="h-1 flex-1 overflow-hidden rounded-full bg-gray-100 dark:bg-gray-800">
            <span class="block h-full rounded-full bg-rose-400" :style="{ width: `${(item.hits / top) * 100}%` }" />
          </span>
          <span class="shrink-0 text-xs text-gray-500 tabular-nums"
            >{{ item.hits.toLocaleString() }} hits · {{ timeAgo(item.last_seen_at) }}</span
          >
        </div>
      </div>
      <Link
        :href="item.redirect_url"
        class="shrink-0 text-xs font-medium text-gray-700 hover:text-gray-900 hover:underline dark:text-gray-300 dark:hover:text-white"
        >Redirect</Link
      >
    </li>
  </ul>
  <p v-else class="px-4.5 py-8 text-center text-sm text-gray-500">No missing pages. Every link lands somewhere.</p>
</template>
