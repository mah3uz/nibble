<script setup lang="ts">
import { useDebounceFn } from '@vueuse/core'
import { ref, watch } from 'vue'
import { Input } from '@/components/ui/input'
import { searchRelationships, type ItemSummary } from '../../lib/relationships'

const props = defineProps<{
  type: string
  scope?: Record<string, unknown>
  selectedIds: string[]
  label: string
  id?: string
}>()
const emit = defineEmits<{ pick: [item: ItemSummary] }>()

const query = ref('')
const results = ref<ItemSummary[]>([])
const searched = ref(false)
const failed = ref<string | null>(null)

const run = useDebounceFn(async () => {
  const term = query.value
  if (!term.trim()) {
    results.value = []
    searched.value = false
    return
  }
  failed.value = null
  try {
    const found = await searchRelationships(props.type, { query: term, scope: props.scope, limit: 8 })
    if (term === query.value) results.value = found
  } catch (error) {
    failed.value = (error as Error).message
    results.value = []
  }
  searched.value = true
}, 200)

watch(query, run)

function choose(item: ItemSummary) {
  emit('pick', item)
  query.value = ''
}
</script>

<template>
  <div class="space-y-1">
    <Input :id="id" v-model="query" type="search" autocomplete="off" role="combobox" :placeholder="label" />
    <ul
      v-if="query.trim()"
      class="rounded-lg border border-gray-300 bg-white p-1 dark:border-gray-700 dark:bg-gray-900"
    >
      <li v-for="item in results" :key="item.id">
        <button
          type="button"
          class="flex w-full cursor-pointer items-center gap-2 rounded-md px-3 py-2 text-start text-sm hover:bg-gray-100 dark:hover:bg-gray-800"
          :class="selectedIds.includes(item.id) && 'text-blue-600'"
          @click="choose(item)"
        >
          <span class="min-w-0 flex-1 truncate">{{ item.title }}</span>
        </button>
      </li>
      <li v-if="!results.length" class="px-3 py-2 text-sm text-gray-500">
        {{ failed ?? (searched ? 'No results.' : 'Searching…') }}
      </li>
    </ul>
  </div>
</template>
