<script setup lang="ts">
import { ArrowDown, ArrowUp } from '@lucide/vue'
import type { Component, FunctionalComponent } from 'vue'
import { Button } from '@/components/ui/button'
import { Checkbox } from '@/components/ui/checkbox'
import CodeCell from './cells/CodeCell.vue'
import DateCell from './cells/DateCell.vue'
import ImageCell from './cells/ImageCell.vue'
import ListCell from './cells/ListCell.vue'
import StatusCell from './cells/StatusCell.vue'
import TitleCell from './cells/TitleCell.vue'
import RowActions from './RowActions.vue'
import type { ListingAction, ListingColumn, ListingColumnType, ListingRow } from './types'

const RowPassthrough: FunctionalComponent = (_, { slots }) => slots.default?.()

const props = defineProps<{
  columns: ListingColumn[]
  rows: ListingRow[]
  actions: ListingAction[]
  sortColumn: string | null
  sortDirection: 'asc' | 'desc'
  selected: Set<number>
  rowMenu?: { component: Component; props: (row: ListingRow) => Record<string, unknown> }
}>()
const emit = defineEmits<{
  sort: [handle: string]
  'update:selected': [Set<number>]
  action: [action: ListingAction, ids: number[]]
  'row-click': [row: ListingRow]
}>()

function onRowClick(row: ListingRow, event: MouseEvent) {
  if ((event.target as HTMLElement).closest('a, button, [role="checkbox"]')) return
  emit('row-click', row)
}

const cellComponents: Partial<Record<ListingColumnType, unknown>> = {
  title: TitleCell,
  status: StatusCell,
  date: DateCell,
  list: ListCell,
  code: CodeCell,
  image: ImageCell,
}

function toggle(id: number) {
  const next = new Set(props.selected)
  if (next.has(id)) next.delete(id)
  else next.add(id)
  emit('update:selected', next)
}

function toggleAll() {
  emit('update:selected', props.selected.size === props.rows.length ? new Set() : new Set(props.rows.map((r) => r.id)))
}
</script>

<template>
  <div class="overflow-x-auto">
    <table class="data-table" :data-has-selections="selected.size > 0 ? '' : null">
      <thead>
        <tr>
          <th class="checkbox-column">
            <Checkbox
              :model-value="rows.length > 0 && selected.size === rows.length"
              aria-label="Select all"
              @update:model-value="toggleAll"
            />
          </th>
          <th v-for="column in columns" :key="column.handle">
            <Button
              v-if="column.sortable"
              variant="ghost"
              size="sm"
              class="-mx-3 -mt-2 -mb-1 text-sm font-medium"
              @click="emit('sort', column.handle)"
            >
              {{ column.label }}
              <ArrowUp v-if="sortColumn === column.handle && sortDirection === 'asc'" class="size-3!" />
              <ArrowDown v-else-if="sortColumn === column.handle" class="size-3!" />
            </Button>
            <template v-else>{{ column.label }}</template>
          </th>
          <th class="actions-column" />
        </tr>
      </thead>
      <tbody>
        <slot name="prepend-rows" :colspan="columns.length + 2" />
        <component
          :is="rowMenu?.component ?? RowPassthrough"
          v-for="row in rows"
          :key="row.id"
          v-bind="rowMenu?.props(row) ?? {}"
        >
          <tr :data-row="selected.has(row.id) ? 'selected' : null" @click="onRowClick(row, $event)">
            <td class="checkbox-column">
              <Checkbox
                :model-value="selected.has(row.id)"
                :aria-label="`Select row ${row.id}`"
                @update:model-value="toggle(row.id)"
              />
            </td>
            <td v-for="column in columns" :key="column.handle">
              <slot
                v-if="$slots[`cell-${column.handle}`]"
                :name="`cell-${column.handle}`"
                :row="row"
                :value="row[column.handle]"
              />
              <component
                :is="cellComponents[column.type]"
                v-else-if="cellComponents[column.type]"
                :value="row[column.handle]"
                :href="column.type === 'title' ? row.edit_url : null"
              />
              <span v-else>{{ row[column.handle] ?? '—' }}</span>
            </td>
            <td class="actions-column">
              <slot name="row-actions" :row="row">
                <RowActions
                  :actions="actions"
                  :handles="row.actions"
                  @run="(action) => emit('action', action, [row.id])"
                />
              </slot>
            </td>
          </tr>
        </component>
        <tr v-if="rows.length === 0 && !$slots['prepend-rows']">
          <td :colspan="columns.length + 2" class="py-8! text-center text-gray-500!">No results.</td>
        </tr>
      </tbody>
    </table>
  </div>
</template>
