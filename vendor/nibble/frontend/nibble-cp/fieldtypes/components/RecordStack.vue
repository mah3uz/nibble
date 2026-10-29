<script setup lang="ts">
import { useDebounceFn } from '@vueuse/core'
import { Check } from '@lucide/vue'
import { ref, watch } from 'vue'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Sheet, SheetContent, SheetDescription, SheetHeader, SheetTitle } from '@/components/ui/sheet'
import { searchRelationships, type ItemSummary } from '../../lib/relationships'
import { latestRequest } from '../relationshipMode'

const PAGE = 20

const props = defineProps<{
  type: string
  scope?: Record<string, unknown>
  selectedIds: string[]
  label: string
  single: boolean
  max: number
  full: boolean
  id?: string
}>()
const emit = defineEmits<{ pick: [item: ItemSummary] }>()

const open = ref(false)
const query = ref('')
const results = ref<ItemSummary[]>([])
const more = ref(false)
const loading = ref(false)
const failed = ref<string | null>(null)
const start = latestRequest()

async function load(reset: boolean) {
  const current = start()
  loading.value = true
  failed.value = null
  try {
    const found = await searchRelationships(props.type, {
      query: query.value,
      scope: props.scope,
      limit: PAGE,
      offset: reset ? 0 : results.value.length,
    })
    if (!current()) return
    results.value = reset ? found : [...results.value, ...found]
    more.value = found.length === PAGE
  } catch (error) {
    if (current()) failed.value = (error as Error).message
  } finally {
    if (current()) loading.value = false
  }
}

const search = useDebounceFn(() => load(true), 200)
watch(open, (isOpen) => isOpen && load(true))
watch(query, () => open.value && search())

function choose(item: ItemSummary) {
  emit('pick', item)
  if (props.single) open.value = false
}
</script>

<template>
  <Button v-if="!full" :id="id" type="button" variant="outline" class="w-full justify-start" @click="open = true">{{
    label
  }}</Button>
  <Sheet v-model:open="open">
    <SheetContent size="narrow" class="gap-0">
      <SheetHeader>
        <SheetTitle>{{ label.replace(/…$/, '') }}</SheetTitle>
        <SheetDescription :class="!full && 'sr-only'" aria-live="polite">{{
          full
            ? `That's the most this field takes (${max}). Remove one to choose another.`
            : 'Search and pick from the list.'
        }}</SheetDescription>
      </SheetHeader>
      <div class="flex min-h-0 flex-1 flex-col gap-3 px-4 pb-4">
        <Input v-model="query" type="search" placeholder="Search…" autocomplete="off" />
        <ul class="min-h-0 flex-1 space-y-1 overflow-y-auto">
          <li v-for="item in results" :key="item.id">
            <button
              type="button"
              class="flex w-full cursor-pointer items-center gap-2 rounded-md px-3 py-2 text-start text-sm enabled:hover:bg-gray-100 disabled:cursor-not-allowed disabled:opacity-50 dark:enabled:hover:bg-gray-800"
              :class="selectedIds.includes(item.id) && 'bg-blue-50 text-blue-600 dark:bg-blue-600 dark:text-blue-50'"
              :aria-pressed="selectedIds.includes(item.id)"
              :disabled="full && !selectedIds.includes(item.id)"
              @click="choose(item)"
            >
              <span class="min-w-0 flex-1 truncate">{{ item.title }}</span>
              <Check v-if="selectedIds.includes(item.id)" class="size-4" />
            </button>
          </li>
          <li v-if="!results.length" class="px-3 py-2 text-sm text-gray-500">
            {{ loading ? 'Loading…' : (failed ?? 'No results.') }}
          </li>
        </ul>
        <Button v-if="more" type="button" variant="outline" :disabled="loading" @click="load(false)">Load more</Button>
      </div>
    </SheetContent>
  </Sheet>
</template>
