<script setup lang="ts">
import { computed } from 'vue'
import { timeAgo } from '@/lib/format'
import type { AwaitingReviewData } from './types'
import ItemList from './ItemList.vue'

const props = defineProps<{ data: AwaitingReviewData }>()
const rows = computed(() =>
  props.data.items.map((item) => ({
    key: item.id,
    title: item.title,
    subtitle: item.user ? `Sent by ${item.user}` : item.path,
    url: item.edit_url,
    since: item.since,
  })),
)
</script>

<template>
  <ItemList :rows="rows" empty-text="Nothing is waiting for you. Nice.">
    <template #badge="{ row }">
      <time
        :datetime="row.since"
        class="shrink-0 rounded-full bg-sky-100 px-2 py-0.5 text-xs text-sky-800 dark:bg-sky-300/10 dark:text-sky-300"
        >waiting {{ timeAgo(row.since).replace(' ago', '') }}</time
      >
    </template>
  </ItemList>
</template>
