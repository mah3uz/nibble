<script setup lang="ts">
import { GripVertical, X } from '@lucide/vue'
import { useSortable } from '@vueuse/integrations/useSortable'
import { computed, ref, useTemplateRef, watch } from 'vue'
import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import type { ItemSummary } from '../../lib/relationships'
import RecordSearch from './RecordSearch.vue'

const props = defineProps<{
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
  if (single.value) return emitIds([item.id])
  if (ids.value.includes(item.id)) return emitIds(ids.value.filter((id) => id !== item.id))
  if (!full.value) emitIds([...ids.value, item.id])
}

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
          known.get(itemId)?.title ?? `Missing item ${itemId}`
        }}</span>
        <Badge v-if="known.get(itemId)?.status" variant="secondary">{{ known.get(itemId)?.status }}</Badge>
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
    <RecordSearch
      v-if="!readOnly && !full && !(single && ids.length)"
      :id="id"
      :type="type"
      :scope="scope"
      :selected-ids="ids"
      :label="label"
      @pick="pick"
    />
  </div>
</template>
