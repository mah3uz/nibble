<script setup lang="ts">
import { ArrowDown, ArrowUp, GripVertical, MoreHorizontal, Plus, Trash2 } from '@lucide/vue'
import { useSortable } from '@vueuse/integrations/useSortable'
import { computed, ref, useTemplateRef, watch } from 'vue'
import { Button } from '@/components/ui/button'
import { DropdownMenu, DropdownMenuContent, DropdownMenuItem, DropdownMenuTrigger } from '@/components/ui/dropdown-menu'
import PublishFields from '../../publish/PublishFields.vue'
import { clone } from '../../lib/clone'
import { rowId } from '../../lib/rowId'
import { moveRow, restoreRow, useUndoToast } from '../rows'
import type { PublishField } from '../types'
import { fieldtypeEmits, fieldtypeProps, useFieldtype } from '../useFieldtype'

type Row = Record<string, unknown> & { _id: string }

const props = defineProps(fieldtypeProps)
const emit = defineEmits(fieldtypeEmits)
const { update, updateMeta, isReadOnly, expose } = useFieldtype(emit, props)
defineExpose(expose)

const fields = computed(() => (props.config.fields as PublishField[]) ?? [])
const rows = ref<Row[]>([...((props.value as Row[] | null) ?? [])])
watch(
  () => props.value,
  (value) => (rows.value = [...((value as Row[] | null) ?? [])]),
)

const max = computed(() => Number(props.config.max_rows) || 0)
const min = computed(() => Number(props.config.min_rows) || 0)
const canAdd = computed(() => !isReadOnly.value && (!max.value || rows.value.length < max.value))
const canRemove = computed(() => !isReadOnly.value && rows.value.length > min.value)
const canMove = computed(() => !isReadOnly.value && props.config.reorderable !== false && rows.value.length > 1)
const addLabel = computed(() => (props.config.add_row as string) || 'Add row')
const offerUndo = useUndoToast()

const listRef = useTemplateRef<HTMLElement>('list')
useSortable(listRef, rows, {
  handle: '.drag-handle',
  forceFallback: true,
  dragClass: 'sortable-drag-clone',
  ghostClass: 'sortable-ghost-placeholder',
  onUpdate: () => queueMicrotask(() => update([...rows.value])),
})

function addRow() {
  const id = rowId()
  const defaults = (props.meta.defaults as Record<string, unknown>) ?? {}
  updateMeta({ ...props.meta, existing: { ...((props.meta.existing as object) ?? {}), [id]: props.meta.new ?? {} } })
  update([...rows.value, { ...clone(defaults), _id: id }])
}

function removeRow(index: number) {
  const row = rows.value[index]!
  update(rows.value.filter((_, position) => position !== index))
  offerUndo('Row removed', () => update(restoreRow(rows.value, row, index)))
}

function moveTo(index: number, to: number) {
  update(moveRow(rows.value, index, to))
}
</script>

<template>
  <div :id="id" class="space-y-2">
    <div ref="list" class="space-y-2">
      <div
        v-for="(row, index) in rows"
        :key="row._id"
        class="flex gap-2 rounded-lg border border-gray-300 bg-white p-2 shadow-ui-sm dark:border-gray-700 dark:bg-gray-900"
        :class="config.mode === 'stacked' ? 'flex-wrap items-center' : 'items-start'"
      >
        <div class="flex items-center gap-1" :class="{ 'pt-8': config.mode !== 'stacked' }">
          <GripVertical
            v-if="!isReadOnly && config.reorderable !== false"
            class="drag-handle size-4 shrink-0 cursor-grab text-gray-400"
          />
        </div>
        <PublishFields
          class="min-w-0"
          :class="config.mode === 'stacked' ? 'order-last w-full' : 'flex-1'"
          :fields="fields"
          :field-path-prefix="`${fieldPathPrefix}.${index}`"
          :meta-path-prefix="`${metaPathPrefix}.existing.${row._id}`"
          :read-only="isReadOnly"
        />
        <div
          v-if="canRemove || canMove"
          class="flex items-center gap-1"
          :class="config.mode === 'stacked' ? 'ms-auto' : 'mt-7'"
        >
          <Button
            v-if="canRemove"
            type="button"
            variant="ghost"
            size="icon-sm"
            :aria-label="`Remove row ${index + 1}`"
            @click="removeRow(index)"
            ><Trash2
          /></Button>
          <DropdownMenu v-if="canMove">
            <DropdownMenuTrigger as-child>
              <Button type="button" variant="ghost" size="icon-sm" :aria-label="`Actions for row ${index + 1}`"
                ><MoreHorizontal
              /></Button>
            </DropdownMenuTrigger>
            <DropdownMenuContent align="end" class="min-w-44">
              <DropdownMenuItem :disabled="index === 0" @select="moveTo(index, index - 1)"
                ><ArrowUp />Move up</DropdownMenuItem
              >
              <DropdownMenuItem :disabled="index === rows.length - 1" @select="moveTo(index, index + 1)"
                ><ArrowDown />Move down</DropdownMenuItem
              >
            </DropdownMenuContent>
          </DropdownMenu>
        </div>
      </div>
    </div>
    <Button v-if="canAdd" type="button" variant="outline" size="sm" @click="addRow"><Plus />{{ addLabel }}</Button>
  </div>
</template>
