<script setup lang="ts">
import { useDebounceFn } from '@vueuse/core'
import { Check } from '@lucide/vue'
import { ComboboxAnchor, ComboboxContent, ComboboxEmpty, ComboboxInput, ComboboxItem, ComboboxRoot } from 'reka-ui'
import { ref, watch } from 'vue'
import { searchRelationships, type ItemSummary } from '../../lib/relationships'
import { latestRequest } from '../relationshipMode'

const props = defineProps<{
  type: string
  scope?: Record<string, unknown>
  selectedIds: string[]
  label: string
  id?: string
}>()
const emit = defineEmits<{ pick: [item: ItemSummary] }>()

const query = ref('')
const open = ref(false)
const results = ref<ItemSummary[]>([])
const searched = ref(false)
const failed = ref<string | null>(null)
const start = latestRequest()

const run = useDebounceFn(async () => {
  const current = start()
  if (!query.value.trim()) {
    results.value = []
    searched.value = false
    return
  }
  failed.value = null
  try {
    const found = await searchRelationships(props.type, { query: query.value, scope: props.scope, limit: 8 })
    if (current()) results.value = found
  } catch (error) {
    if (!current()) return
    failed.value = (error as Error).message
    results.value = []
  }
  if (current()) searched.value = true
}, 200)

watch(query, (term) => {
  open.value = !!term.trim()
  searched.value = false
  run()
})

function choose(event: Event, item: ItemSummary) {
  event.preventDefault()
  emit('pick', item)
  query.value = ''
}
</script>

<template>
  <ComboboxRoot
    :open="open"
    :model-value="selectedIds"
    multiple
    ignore-filter
    :reset-search-term-on-blur="false"
    class="space-y-1"
    @update:open="(next: boolean) => (open = next && !!query.trim())"
  >
    <ComboboxAnchor>
      <ComboboxInput
        :id="id"
        v-model="query"
        type="search"
        autocomplete="off"
        :placeholder="label"
        class="block h-10 w-full min-w-0 appearance-none rounded-lg border border-gray-300 bg-white px-3 py-2 st-text-legibility text-base leading-[1.375rem] text-gray-925 antialiased shadow-ui-sm outline-none placeholder:text-gray-500 focus-visible:focus-outline dark:border-gray-700 dark:bg-gray-900 dark:text-gray-300 dark:inset-shadow-2xs dark:inset-shadow-black dark:placeholder:text-gray-400/85"
      />
    </ComboboxAnchor>
    <ComboboxContent
      class="rounded-lg border border-gray-300 bg-white p-1 dark:border-gray-700 dark:bg-gray-900"
      :aria-label="label.replace(/…$/, '')"
    >
      <ComboboxItem
        v-for="item in results"
        :key="item.id"
        :value="item.id"
        class="flex w-full cursor-pointer items-center gap-2 rounded-md px-3 py-2 text-start text-sm data-highlighted:bg-gray-100 data-[state=checked]:text-blue-600 dark:data-highlighted:bg-gray-800 dark:data-[state=checked]:text-blue-400"
        @select="choose($event, item)"
      >
        <span class="min-w-0 flex-1 truncate">{{ item.title }}</span>
        <Check v-if="selectedIds.includes(item.id)" class="size-4 shrink-0" aria-hidden="true" />
      </ComboboxItem>
      <ComboboxEmpty class="px-3 py-2 text-sm text-gray-500">
        {{ failed ?? (searched ? 'No results.' : 'Searching…') }}
      </ComboboxEmpty>
    </ComboboxContent>
  </ComboboxRoot>
</template>
