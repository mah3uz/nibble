<script setup lang="ts">
import { computed } from 'vue'
import { timeAgo } from '@/lib/format'
import type { ScheduledData } from './types'
import ItemList from './ItemList.vue'

const props = defineProps<{ data: ScheduledData }>()
const rows = computed(() =>
  props.data.items.map((item) => ({
    key: `${item.type}-${item.id}`,
    title: item.title,
    subtitle: item.path,
    url: item.edit_url,
    published_at: item.published_at,
  })),
)
</script>

<template>
  <ItemList :rows="rows" empty-text="Nothing is scheduled to go live.">
    <template #badge="{ row }">
      <time
        :datetime="row.published_at"
        :title="new Date(row.published_at).toLocaleString('en-AU', { dateStyle: 'medium', timeStyle: 'short' })"
        class="shrink-0 rounded-full bg-amber-100 px-2 py-0.5 text-xs text-amber-800 dark:bg-amber-300/10 dark:text-amber-300"
        >{{ timeAgo(row.published_at) }}</time
      >
    </template>
  </ItemList>
</template>
