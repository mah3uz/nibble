<script setup lang="ts">
import { computed } from 'vue'
import AreaChart from '@/components/admin/charts/AreaChart.vue'
import type { ActivityChartData } from './types'

const props = defineProps<{ data: ActivityChartData }>()

const COLORS: Record<string, { color: string; dot: string }> = {
  edits: { color: 'text-indigo-500', dot: 'bg-indigo-500' },
  published: { color: 'text-emerald-500', dot: 'bg-emerald-500' },
}
const series = computed(() => props.data.series.map((s) => ({ ...s, ...COLORS[s.key] })))
const totals = computed(() => series.value.map((s) => ({ ...s, total: s.values.reduce((a, b) => a + b, 0) })))
</script>

<template>
  <div class="px-4.5 pt-4 pb-3">
    <div class="mb-3 flex flex-wrap gap-x-6 gap-y-1">
      <p v-for="s in totals" :key="s.key" class="flex items-center gap-2 text-sm text-gray-600 dark:text-gray-400">
        <span :class="['size-2.5 rounded-full', s.dot]" />{{ s.label }}
        <span class="font-semibold text-gray-900 tabular-nums dark:text-white">{{ s.total.toLocaleString() }}</span>
      </p>
      <p class="ms-auto text-xs text-gray-500">Last 30 days</p>
    </div>
    <AreaChart :series="series" :start="data.start" />
  </div>
</template>
