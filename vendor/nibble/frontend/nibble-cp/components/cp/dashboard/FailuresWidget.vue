<script setup lang="ts">
import { computed } from 'vue'
import { timeAgo } from '@/lib/format'
import type { FailuresData } from './types'
import ItemList from './ItemList.vue'

const props = defineProps<{ data: FailuresData }>()
const rows = computed(() =>
  props.data.items.map((item, index) => ({
    key: index,
    title: item.title,
    subtitle: item.detail,
    url: item.url,
    kind: item.kind,
    at: item.at,
  })),
)
</script>

<template>
  <ItemList :rows="rows" empty-text="No failed webhooks or jobs.">
    <template #badge="{ row }">
      <span class="flex shrink-0 items-center gap-2 text-xs text-gray-500">
        <span class="rounded-full bg-rose-100 px-2 py-0.5 text-rose-800 dark:bg-rose-300/10 dark:text-rose-300">{{
          row.kind
        }}</span>
        <time :datetime="row.at">{{ timeAgo(row.at) }}</time>
      </span>
    </template>
  </ItemList>
</template>
