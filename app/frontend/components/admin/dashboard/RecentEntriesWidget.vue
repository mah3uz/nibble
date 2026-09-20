<script setup lang="ts">
import { computed } from 'vue'
import StatusIndicator from '@/components/admin/page/StatusIndicator.vue'
import type { RecentEntriesData } from './types'
import ItemList from './ItemList.vue'

const props = defineProps<{ data: RecentEntriesData }>()
const rows = computed(() =>
  props.data.items.map((item) => ({
    key: item.id,
    title: item.title,
    subtitle: item.path,
    url: item.edit_url,
    status: item.status,
    live: item.live,
  })),
)
</script>

<template>
  <ItemList :rows="rows" empty-text="Nothing has been edited yet.">
    <template #badge="{ row }"><StatusIndicator :status="row.status" :live="row.live" /></template>
  </ItemList>
</template>
