<script setup lang="ts">
import { Link } from '@inertiajs/vue3'
import { computed } from 'vue'
import type { ContentMixData, MixKey } from './types'

const props = defineProps<{ data: ContentMixData }>()

const PARTS: { key: MixKey; label: string; bar: string }[] = [
  { key: 'published', label: 'Published', bar: 'bg-emerald-500' },
  { key: 'scheduled', label: 'Scheduled', bar: 'bg-amber-400' },
  { key: 'in_review', label: 'In review', bar: 'bg-sky-500' },
  { key: 'draft', label: 'Draft', bar: 'bg-gray-300 dark:bg-gray-600' },
  { key: 'unpublished', label: 'Unpublished', bar: 'bg-rose-400' },
]

const total = computed(() => props.data.collections.reduce((sum, c) => sum + c.total, 0))
const sums = computed(() =>
  PARTS.map((part) => ({ ...part, count: props.data.collections.reduce((sum, c) => sum + c.counts[part.key], 0) })),
)
const width = (count: number, of: number) => `${of ? (count / of) * 100 : 0}%`
</script>

<template>
  <div class="px-4.5 py-4">
    <p class="flex items-baseline gap-2">
      <span class="text-3xl font-semibold tracking-tight text-gray-900 tabular-nums dark:text-white">{{
        total.toLocaleString()
      }}</span>
      <span class="text-sm text-gray-600 dark:text-gray-400">entries</span>
    </p>
    <div class="mt-3 flex h-2.5 gap-0.5 overflow-hidden rounded-full bg-gray-100 dark:bg-gray-800">
      <span
        v-for="part in sums.filter((p) => p.count)"
        :key="part.key"
        :class="part.bar"
        :style="{ width: width(part.count, total) }"
        :title="`${part.label}: ${part.count}`"
      />
    </div>
    <ul class="mt-3 flex flex-wrap gap-x-3.5 gap-y-1 text-xs text-gray-600 dark:text-gray-400">
      <li v-for="part in sums" :key="part.key" class="flex items-center gap-1.5">
        <span :class="['size-2 rounded-full', part.bar]" />{{ part.label }}
        <span class="font-medium text-gray-900 tabular-nums dark:text-white">{{ part.count }}</span>
      </li>
    </ul>
    <ul class="mt-4 space-y-3 border-t border-gray-100 pt-4 dark:border-gray-800">
      <li v-for="collection in data.collections" :key="collection.handle">
        <Link :href="collection.url" class="group block">
          <span class="mb-1.5 flex items-baseline justify-between text-sm">
            <span class="font-medium text-gray-900 group-hover:underline dark:text-white">{{ collection.title }}</span>
            <span class="text-gray-500 tabular-nums">{{ collection.total }}</span>
          </span>
          <span class="flex h-1.5 gap-px overflow-hidden rounded-full bg-gray-100 dark:bg-gray-800">
            <span
              v-for="part in PARTS.filter((p) => collection.counts[p.key])"
              :key="part.key"
              :class="part.bar"
              :style="{ width: width(collection.counts[part.key], collection.total) }"
            />
          </span>
        </Link>
      </li>
    </ul>
  </div>
</template>
