<script setup lang="ts">
import { Link } from '@inertiajs/vue3'
import SparkLine from '@/components/cp/charts/SparkLine.vue'
import type { OverviewData } from './types'

defineProps<{ data: OverviewData }>()

const TONE: Record<string, string> = {
  published: 'text-emerald-500',
  edits: 'text-indigo-500',
  submissions: 'text-sky-500',
  uploads: 'text-fuchsia-500',
}
</script>

<template>
  <ul class="grid grid-cols-2 gap-px bg-gray-100 lg:grid-cols-4 dark:bg-gray-800">
    <li v-for="tile in data.tiles" :key="tile.key" class="bg-white dark:bg-gray-850">
      <Link
        :href="tile.url"
        class="group block px-3.5 pt-4 transition-colors hover:bg-gray-50 sm:px-4.5 dark:hover:bg-gray-900/60"
      >
        <p class="text-sm text-gray-600 dark:text-gray-400">{{ tile.label }}</p>
        <p class="mt-1 text-2xl font-semibold tracking-tight text-gray-900 tabular-nums sm:text-3xl dark:text-white">
          {{ tile.total.toLocaleString() }}
        </p>
        <p class="text-xs text-gray-500">Last 30 days</p>
        <div :class="['-mx-3.5 mt-2 sm:-mx-4.5', TONE[tile.key] ?? 'text-indigo-500']">
          <SparkLine :values="tile.series" />
        </div>
      </Link>
    </li>
  </ul>
</template>
