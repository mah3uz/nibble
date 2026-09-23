<script setup lang="ts">
import { computed } from 'vue'
import { timeAgo } from '@/lib/format'
import type { FormSubmissionsData } from './types'
import ItemList from './ItemList.vue'

const props = defineProps<{ data: FormSubmissionsData }>()
const rows = computed(() =>
  props.data.items.map((item) => ({
    key: item.id,
    title: item.summary || 'Submission',
    subtitle: item.form,
    url: item.url,
    unread: item.unread,
    at: item.created_at,
  })),
)
</script>

<template>
  <div>
    <p
      v-if="data.unread"
      class="border-b border-gray-100 bg-sky-50/60 px-4.5 py-2 text-xs text-sky-800 dark:border-gray-800 dark:bg-sky-400/5 dark:text-sky-300"
    >
      {{ data.unread }} unread {{ data.unread === 1 ? 'submission' : 'submissions' }}
    </p>
    <ItemList :rows="rows" empty-text="No one has filled in a form yet.">
      <template #badge="{ row }">
        <span class="flex shrink-0 items-center gap-2 text-xs text-gray-500">
          <span v-if="row.unread" class="size-2 rounded-full bg-sky-500" title="Unread" />
          <time :datetime="row.at">{{ timeAgo(row.at) }}</time>
        </span>
      </template>
    </ItemList>
  </div>
</template>
