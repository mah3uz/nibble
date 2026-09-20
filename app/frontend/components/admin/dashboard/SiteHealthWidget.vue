<script setup lang="ts">
import { Link } from '@inertiajs/vue3'
import type { SiteHealthData } from './types'

defineProps<{ data: SiteHealthData }>()

const SUMMARY = {
  ok: { text: 'Everything is running', tone: 'text-emerald-700 dark:text-emerald-300', ring: 'bg-emerald-500' },
  degraded: { text: 'Something needs a look', tone: 'text-amber-700 dark:text-amber-300', ring: 'bg-amber-400' },
  down: { text: 'Part of the site is down', tone: 'text-rose-700 dark:text-rose-300', ring: 'bg-rose-500' },
}
const DOT = { ok: 'bg-emerald-500', warn: 'bg-amber-400', fail: 'bg-rose-500', skip: 'bg-gray-300 dark:bg-gray-600' }
const NAMES: Record<string, string> = {
  database: 'Database',
  queue: 'Job queue',
  storage: 'File storage',
  ssr: 'Server rendering',
}
</script>

<template>
  <div>
    <Link
      :href="data.url"
      class="flex items-center gap-3 border-b border-gray-100 px-4.5 py-3.5 transition-colors hover:bg-gray-50 dark:border-gray-800 dark:hover:bg-gray-900/60"
    >
      <span class="relative flex size-3">
        <span
          v-if="data.status !== 'ok'"
          :class="[
            'absolute inset-0 animate-ping rounded-full opacity-60 motion-reduce:animate-none',
            SUMMARY[data.status].ring,
          ]"
        />
        <span :class="['relative size-3 rounded-full', SUMMARY[data.status].ring]" />
      </span>
      <span :class="['text-sm font-medium', SUMMARY[data.status].tone]">{{ SUMMARY[data.status].text }}</span>
    </Link>
    <ul>
      <li
        v-for="check in data.checks"
        :key="check.name"
        class="flex items-start gap-3 border-b border-gray-100 px-4.5 py-2.5 last:border-0 dark:border-gray-800"
      >
        <span :class="['mt-1.5 size-2 shrink-0 rounded-full', DOT[check.status]]" />
        <span class="min-w-0 flex-1">
          <span class="block text-sm text-gray-900 dark:text-white">{{ NAMES[check.name] ?? check.name }}</span>
          <span class="block truncate text-xs text-gray-500" :title="check.message">{{ check.message }}</span>
        </span>
        <span class="shrink-0 pt-0.5 text-xs text-gray-500 tabular-nums">{{ check.ms }} ms</span>
      </li>
    </ul>
  </div>
</template>
