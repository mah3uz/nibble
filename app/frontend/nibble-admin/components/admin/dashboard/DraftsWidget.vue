<script setup lang="ts">
import { computed } from 'vue'
import type { DraftsData } from './types'
import ItemList from './ItemList.vue'

const props = defineProps<{ data: DraftsData }>()
const rows = computed(() =>
  props.data.items.map((item) => ({
    key: `${item.type}-${item.id}`,
    title: item.title,
    subtitle: item.path,
    url: item.edit_url,
    user: item.user,
  })),
)
</script>

<template>
  <ItemList :rows="rows" empty-text="No unpublished changes.">
    <template #badge="{ row }">
      <span v-if="row.user" class="shrink-0 text-xs text-gray-500">{{ row.user }}</span>
    </template>
  </ItemList>
</template>
