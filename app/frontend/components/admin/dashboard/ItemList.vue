<script
  setup
  lang="ts"
  generic="Row extends { key: string | number; title: string; subtitle?: string | null; url: string }"
>
import { Link } from '@inertiajs/vue3'

defineProps<{ rows: Row[]; emptyText: string }>()
defineSlots<{ badge?(props: { row: Row }): unknown }>()
</script>

<template>
  <ul v-if="rows.length">
    <li v-for="row in rows" :key="row.key" class="border-b border-gray-100 last:border-0 dark:border-gray-800">
      <Link
        :href="row.url"
        class="flex items-center justify-between gap-3 px-4.5 py-2.5 transition-colors hover:bg-gray-50 dark:hover:bg-gray-900/60"
      >
        <span class="min-w-0 flex-1">
          <span class="block truncate text-sm font-medium text-gray-900 dark:text-white">{{ row.title }}</span>
          <span v-if="row.subtitle" class="block truncate text-xs text-gray-500">{{ row.subtitle }}</span>
        </span>
        <slot name="badge" :row="row" />
      </Link>
    </li>
  </ul>
  <p v-else class="px-4.5 py-8 text-center text-sm text-gray-500">{{ emptyText }}</p>
</template>
