<script setup lang="ts">
import { useSortable } from '@vueuse/integrations/useSortable'
import { computed, ref, useTemplateRef, watch } from 'vue'
import { toast } from 'vue-sonner'
import { clone } from '../../lib/clone'
import { rowId } from '../../lib/rowId'
import { useSectionActions } from '../../publish/context'
import { offersFullscreen, useOutsideFullscreenLayer, showsPreviews } from '../display'
import { addableGroups, expandSet, hasRoom } from '../replicatorSets'
import { moveRow, restoreRow, useUndoToast } from '../rows'
import { copySet, pastedContent, pasteTarget, useCopiedSet } from '../setClipboard'
import type { PublishSetGroup } from '../types'
import { fieldtypeEmits, fieldtypeProps, useFieldtype } from '../useFieldtype'
import FullscreenLayer from './FullscreenLayer.vue'
import ReplicatorSet from './ReplicatorSet.vue'
import SetPicker from './SetPicker.vue'

type Row = Record<string, unknown> & { _id: string; type: string; enabled?: boolean }

const props = defineProps(fieldtypeProps)
const emit = defineEmits(fieldtypeEmits)
const { update, updateMeta, isReadOnly, defineFieldActions, expose } = useFieldtype(emit, props)
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
const addable = computed(() => addableGroups(groups.value, rows.value))
const showAdd = computed(() => canAdd.value && addable.value.length > 0)
const sectionActions = useSectionActions()
const addInHeader = computed(() => props.config.button_position === 'header' && !!sectionActions && !fullscreen.value)
const collapsed = ref(new Set<string>((props.meta.collapsed as string[]) ?? []))
const accordion = computed(() => props.config.collapse === 'accordion')
const copied = useCopiedSet()
const offerUndo = useUndoToast()
const fullscreen = ref(false)
const previews = computed(() => showsPreviews(props.config))

defineFieldActions(
  offersFullscreen(props.config)
    ? [
        {
          title: 'Full screen',
          icon: () => (fullscreen.value ? 'fullscreen-close' : 'fullscreen-open'),
          run: () => (fullscreen.value = !fullscreen.value),
          visible: useOutsideFullscreenLayer(),
          visibleWhenReadOnly: true,
        },
      ]
    : [],
)

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

function existingMeta(id: string) {
  return ((props.meta.existing as Record<string, Record<string, unknown>>) ?? {})[id] ?? {}
}

function newMeta(handle: string) {
  return ((props.meta.new as Record<string, Record<string, unknown>>) ?? {})[handle] ?? {}
}

function insert(at: number, row: Omit<Row, '_id' | 'type'> & { type: string }, meta: unknown) {
  const id = rowId()
  withMeta(id, meta)
  const next = [...rows.value]
  next.splice(at, 0, { ...row, _id: id })
  update(next)
  expand(id)
}

function addSet(handle: string, at = rows.value.length) {
  const defaults = ((props.meta.defaults as Record<string, object>) ?? {})[handle] ?? {}
  insert(at, { ...clone(defaults), type: handle, enabled: true }, newMeta(handle))
}

function paste(at = rows.value.length) {
  const source = copied.value
  const set = pasteTarget(addable.value, source)
  if (!set || !source) return
  const { values, meta } = pastedContent(set, clone(source))
  insert(at, { ...values, type: set.handle, enabled: true }, { ...newMeta(set.handle), ...meta })
}

function duplicate(index: number) {
  const source = rows.value[index]!
  insert(index + 1, clone(source), clone(existingMeta(source._id)))
}

function remove(index: number) {
  const row = rows.value[index]!
  update(rows.value.filter((_, position) => position !== index))
  offerUndo('Block removed', () => update(restoreRow(rows.value, row, index)))
}

function move(index: number, to: number) {
  update(moveRow(rows.value, index, to))
}

function copy(row: Row) {
  const { _id, ...values } = row
  copySet({ type: row.type, values: clone(values), meta: clone(existingMeta(_id)) })
  toast.success('Block copied')
}

function setEnabled(index: number, enabled: boolean) {
  update(rows.value.map((row, position) => (position === index ? { ...row, enabled } : row)))
}

function expand(id: string) {
  collapsed.value = expandSet(
    collapsed.value,
    rows.value.map((row) => row._id),
    id,
    accordion.value,
  )
}

function toggle(id: string) {
  if (collapsed.value.has(id)) return expand(id)
  collapsed.value = new Set(collapsed.value).add(id)
}
</script>

<template>
  <div :id="id" class="space-y-2">
    <FullscreenLayer v-model:open="fullscreen" :title="(config.display as string) || handle">
      <div v-if="rows.length > 1" class="flex justify-end gap-3 text-xs">
        <button
          type="button"
          class="text-muted-foreground underline underline-offset-2 hover:text-foreground"
          @click="collapsed = new Set(rows.map((row) => row._id))"
        >
          Collapse all
        </button>
        <button
          v-if="!accordion"
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
          :groups="addable"
          :collapsed="collapsed.has(row._id)"
          :previews="previews"
          :read-only="isReadOnly"
          :can-add="showAdd && config.insert_below !== false"
          :can-duplicate="canAdd && sets.some((set) => set.handle === row.type && hasRoom(set, rows))"
          menu
          :can-move-up="!isReadOnly && index > 0"
          :can-move-down="!isReadOnly && index < rows.length - 1"
          :field-path-prefix="`${fieldPathPrefix}.${index}`"
          :meta-path-prefix="`${metaPathPrefix}.existing.${row._id}`"
          @toggle="toggle(row._id)"
          @duplicate="duplicate(index)"
          @remove="remove(index)"
          @move="(delta) => move(index, index + delta)"
          @copy="copy(row)"
          @enable="(enabled) => setEnabled(index, enabled)"
          @add-below="(handle) => addSet(handle, index + 1)"
          @paste-below="paste(index + 1)"
        />
      </div>
      <p v-if="addInHeader && !rows.length" class="text-sm text-muted-foreground">Nothing added yet.</p>
      <Teleport v-if="showAdd && addInHeader" defer :to="`#${sectionActions}`">
        <SetPicker
          :groups="addable"
          can-paste
          :label="(config.button_label as string) || undefined"
          @pick="(handle) => addSet(handle)"
          @paste="paste()"
        />
      </Teleport>
      <SetPicker
        v-else-if="showAdd"
        :groups="addable"
        can-paste
        :label="(config.button_label as string) || undefined"
        @pick="(handle) => addSet(handle)"
        @paste="paste()"
      />
    </FullscreenLayer>
  </div>
</template>
