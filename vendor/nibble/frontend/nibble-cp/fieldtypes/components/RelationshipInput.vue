<script setup lang="ts">
import { GripVertical, X } from '@lucide/vue'
import { useSortable } from '@vueuse/integrations/useSortable'
import { computed, onMounted, ref, useTemplateRef, watch } from 'vue'
import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import { statusLabel } from '@/lib/format'
import type { ItemSummary } from '../../lib/relationships'
import { searchRelationships } from '../../lib/relationships'
import type { CreateTarget } from '../../lib/relationships'
import { nextIds, normalizeMode, pickerFor, probeLimit } from '../relationshipMode'
import RecordCreate from './RecordCreate.vue'
import RecordSearch from './RecordSearch.vue'
import RecordSelect from './RecordSelect.vue'
import RecordStack from './RecordStack.vue'
import RecordTypeahead from './RecordTypeahead.vue'

const props = defineProps<{
  mode?: unknown
  type: string
  value: unknown
  meta: Record<string, unknown>
  scope: Record<string, unknown>
  maxItems: number
  readOnly: boolean
  label: string
  id?: string
}>()
const emit = defineEmits<{ update: [value: unknown]; updateMeta: [meta: Record<string, unknown>] }>()

const single = computed(() => props.maxItems === 1)
const ids = ref<string[]>([])
watch(
  () => props.value,
  (value) => (ids.value = Array.isArray(value) ? value.map(String) : value ? [String(value)] : []),
  { immediate: true },
)
const known = computed(() => new Map(((props.meta.data as ItemSummary[]) ?? []).map((item) => [String(item.id), item])))
const full = computed(() => props.maxItems > 0 && ids.value.length >= props.maxItems && !single.value)

function emitIds(next: string[]) {
  emit('update', single.value ? (next[0] ?? null) : next)
}

function pick(item: ItemSummary) {
  if (!known.value.has(item.id))
    emit('updateMeta', { ...props.meta, data: [...((props.meta.data as ItemSummary[]) ?? []), item] })
  const next = nextIds(ids.value, item.id, { single: single.value, max: props.maxItems })
  if (next !== ids.value) emitIds(next)
}

const mode = computed(() => normalizeMode(props.mode))
const options = ref<ItemSummary[] | null>(null)
const picker = computed(() => pickerFor(mode.value, props.readOnly ? 0 : (options.value?.length ?? null)))
const creatable = computed(() => ((props.meta.creatable as CreateTarget[]) ?? []).filter((target) => target.handle))
const choosing = computed(() => !props.readOnly && !(single.value && ids.value.length))
const picking = computed(() => choosing.value && !full.value)

onMounted(async () => {
  const limit = probeLimit(mode.value)
  if (!limit || props.readOnly) return
  try {
    options.value = await searchRelationships(props.type, { query: '', scope: props.scope, limit })
  } catch {
    options.value = Array.from({ length: limit }, () => ({ id: '', title: '' }))
  }
})

const listRef = useTemplateRef<HTMLElement>('list')
useSortable(listRef, ids, {
  handle: '.drag-handle',
  forceFallback: true,
  dragClass: 'sortable-drag-clone',
  ghostClass: 'sortable-ghost-placeholder',
  onUpdate: () => queueMicrotask(() => emitIds([...ids.value])),
})
</script>

<template>
  <div class="space-y-2">
    <div v-if="ids.length" ref="list" class="space-y-2">
      <div
        v-for="itemId in ids"
        :key="itemId"
        class="flex h-10 items-center gap-2 rounded-lg border border-gray-300 bg-white ps-2 pe-1 text-base text-gray-900 shadow-ui-sm dark:border-gray-700 dark:bg-gray-900 dark:text-gray-300"
      >
        <GripVertical v-if="!single && !readOnly" class="drag-handle size-4 shrink-0 cursor-grab text-gray-400" />
        <span class="flex-1 truncate" :class="{ 'text-destructive': !known.get(itemId) }">{{
          known.get(itemId)?.title ?? "An item that's been deleted or you can't see"
        }}</span>
        <Badge v-if="known.get(itemId)?.status" variant="secondary">{{
          statusLabel(known.get(itemId)!.status!)
        }}</Badge>
        <Button
          type="button"
          variant="ghost"
          size="icon-sm"
          :disabled="readOnly"
          :aria-label="`Remove ${known.get(itemId)?.title ?? itemId}`"
          @click="emitIds(ids.filter((id) => id !== itemId))"
          ><X
        /></Button>
      </div>
    </div>
    <RecordStack
      v-if="choosing && picker === 'stack'"
      :id="id"
      :type="type"
      :scope="scope"
      :selected-ids="ids"
      :label="label"
      :single="single"
      :max="maxItems"
      :full="full"
      @pick="pick"
    />
    <template v-if="picking">
      <RecordSelect
        v-if="picker === 'select'"
        :id="id"
        :options="options ?? []"
        :selected-ids="ids"
        :label="label"
        @pick="pick"
      />
      <RecordTypeahead
        v-else-if="picker === 'typeahead'"
        :id="id"
        :type="type"
        :scope="scope"
        :selected-ids="ids"
        :label="label"
        @pick="pick"
      />
      <RecordSearch
        v-else-if="picker === 'search'"
        :id="id"
        :type="type"
        :scope="scope"
        :selected-ids="ids"
        :label="label"
        @pick="pick"
      />
    </template>
    <RecordCreate
      v-if="picking && picker !== 'loading' && creatable.length"
      :type="type"
      :targets="creatable"
      @created="pick"
    />
  </div>
</template>
