<script setup lang="ts">
import { Link } from '@inertiajs/vue3'
import SparkLine from '@/components/admin/charts/SparkLine.vue'
import type { OverviewData, OverviewTile } from './types'

defineProps<{ data: OverviewData }>()

const TONE: Record<string, string> = {
  published: 'text-emerald-500',
  edits: 'text-indigo-500',
  submissions: 'text-sky-500',
  uploads: 'text-fuchsia-500',
}

function change(tile: OverviewTile) {
  if (!tile.previous) return tile.total ? { text: 'New', up: true } : null
  const percent = Math.round(((tile.total - tile.previous) / tile.previous) * 100)
  return { text: `${percent > 0 ? '+' : ''}${percent}%`, up: percent >= 0 }
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
        <p class="mt-1 flex items-baseline gap-2">
          <span class="text-2xl font-semibold tracking-tight text-gray-900 tabular-nums sm:text-3xl dark:text-white">{{
            tile.total.toLocaleString()
          }}</span>
          <span
            v-if="change(tile)"
            :class="[
              'rounded-full px-1.5 py-0.5 text-xs font-medium tabular-nums',
              change(tile)!.up
                ? 'bg-emerald-50 text-emerald-700 dark:bg-emerald-400/10 dark:text-emerald-300'
                : 'bg-rose-50 text-rose-700 dark:bg-rose-400/10 dark:text-rose-300',
            ]"
            >{{ change(tile)!.text }}</span
          >
        </p>
        <p class="text-xs text-gray-500">Last 30 days · {{ tile.previous.toLocaleString() }} the 30 before</p>
        <div :class="['-mx-3.5 mt-2 sm:-mx-4.5', TONE[tile.key] ?? 'text-indigo-500']">
          <SparkLine :values="tile.series" />
        </div>
      </Link>
    </li>
  </ul>
</template>
