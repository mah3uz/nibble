<script setup lang="ts">
import { useSortable } from '@vueuse/integrations/useSortable'
import { computed, ref, useTemplateRef, watch } from 'vue'
import { clone } from '../../lib/clone'
import { rowId } from '../../lib/rowId'
import type { PublishSetGroup } from '../types'
import { fieldtypeEmits, fieldtypeProps, useFieldtype } from '../useFieldtype'
import ReplicatorSet from './ReplicatorSet.vue'
import SetPicker from './SetPicker.vue'

type Row = Record<string, unknown> & { _id: string; type: string; enabled?: boolean }

const props = defineProps(fieldtypeProps)
const emit = defineEmits(fieldtypeEmits)
const { update, updateMeta, isReadOnly, expose } = useFieldtype(emit, props)
defineExpose(expose)

const groups = computed(() => (props.config.sets as PublishSetGroup[]) ?? [])
const sets = computed(() => groups.value.flatMap((group) => group.sets))
const rows = ref<Row[]>([...((props.value as Row[] | null) ?? [])])
watch(
  () => props.value,
  (value) => (rows.value = [...((value as Row[] | null) ?? [])]),
)

const max = computed(() => Number(props.config.max_sets) || 0)
const canAdd = computed(() => !isReadOnly.value && (!max.value || rows.value.length < max.value))
const collapsed = ref(new Set<string>((props.meta.collapsed as string[]) ?? []))

const listRef = useTemplateRef<HTMLElement>('list')
useSortable(listRef, rows, {
  handle: '.drag-handle',
  forceFallback: true,
  dragClass: 'sortable-drag-clone',
  ghostClass: 'sortable-ghost-placeholder',
  onUpdate: () => queueMicrotask(() => update([...rows.value])),
})

function withMeta(id: string, meta: unknown) {
  updateMeta({ ...props.meta, existing: { ...((props.meta.existing as object) ?? {}), [id]: meta } })
}

function addSet(handle: string, at = rows.value.length) {
  const id = rowId()
  const defaults = ((props.meta.defaults as Record<string, object>) ?? {})[handle] ?? {}
  withMeta(id, ((props.meta.new as Record<string, unknown>) ?? {})[handle] ?? {})
  const next = [...rows.value]
  next.splice(at, 0, { ...clone(defaults), type: handle, _id: id, enabled: true })
  update(next)
}

function duplicate(index: number) {
  const source = rows.value[index]!
  const id = rowId()
  withMeta(id, clone(((props.meta.existing as Record<string, unknown>) ?? {})[source._id] ?? {}))
  const next = [...rows.value]
  next.splice(index + 1, 0, { ...clone(source), _id: id })
  update(next)
}

function setEnabled(index: number, enabled: boolean) {
  update(rows.value.map((row, position) => (position === index ? { ...row, enabled } : row)))
}

function toggle(id: string) {
  const next = new Set(collapsed.value)
  if (next.has(id)) next.delete(id)
  else next.add(id)
  collapsed.value = next
}
</script>

<template>
  <div :id="id" class="space-y-2">
    <div v-if="rows.length > 1" class="flex justify-end gap-3 text-xs">
      <button
        type="button"
        class="text-muted-foreground underline underline-offset-2 hover:text-foreground"
        @click="collapsed = new Set(rows.map((row) => row._id))"
      >
        Collapse all
      </button>
      <button
        type="button"
        class="text-muted-foreground underline underline-offset-2 hover:text-foreground"
        @click="collapsed = new Set()"
      >
        Expand all
      </button>
    </div>
    <div ref="list" class="space-y-2">
      <ReplicatorSet
        v-for="(row, index) in rows"
        :key="row._id"
        :row="row"
        :set="sets.find((set) => set.handle === row.type)"
        :groups="groups"
        :collapsed="collapsed.has(row._id)"
        :read-only="isReadOnly"
        :can-add="canAdd"
        :field-path-prefix="`${fieldPathPrefix}.${index}`"
        :meta-path-prefix="`${metaPathPrefix}.existing.${row._id}`"
        @toggle="toggle(row._id)"
        @duplicate="duplicate(index)"
        @remove="update(rows.filter((_, position) => position !== index))"
        @enable="(enabled) => setEnabled(index, enabled)"
        @add-below="(handle) => addSet(handle, index + 1)"
      />
    </div>
    <SetPicker
      v-if="canAdd"
      :groups="groups"
      :label="(config.button_label as string) || undefined"
      @pick="(handle) => addSet(handle)"
    />
  </div>
</template>
