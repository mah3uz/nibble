<script setup lang="ts">
import { Download } from '@lucide/vue'
import { computed, toRef } from 'vue'
import { useActions } from '@/components/cp/actions/useActions'
import { Button } from '@/components/ui/button'
import BulkActionsBar from './BulkActionsBar.vue'
import { buildQuery } from './buildQuery'
import ColumnPicker from './ColumnPicker.vue'
import ListingFilters from './ListingFilters.vue'
import ListingPagination from './ListingPagination.vue'
import ListingSearch from './ListingSearch.vue'
import ListingTable from './ListingTable.vue'
import PresetTabs from './PresetTabs.vue'
import type { ListingAction, ListingProps, ListingRow } from './types'
import { useListing } from './useListing'

const props = withDefaults(defineProps<{ listing: ListingProps; exportable?: boolean }>(), { exportable: true })
const emit = defineEmits<{ 'row-click': [row: ListingRow] }>()
const listing = toRef(props, 'listing')
const state = useListing(listing)
const { run } = useActions(props.listing.handle)

const visibleColumns = computed(() => props.listing.columns.filter((c) => c.visible))
const currentQuery = computed(() => buildQuery({ q: state.q.value, ...state.filters }))
const exportUrl = computed(() => {
  const query = new URLSearchParams(currentQuery.value as Record<string, string>).toString()
  return `${window.location.pathname}.csv${query ? `?${query}` : ''}`
})

async function runAction(action: ListingAction, ids: number[]) {
  await run(action, ids)
  state.clearSelection()
}

const bulkActions = computed(() => {
  if (state.selected.value.size === 0) return []
  const selectedRows = props.listing.rows.filter((r) => state.selected.value.has(r.id))
  return props.listing.actions.filter(
    (action) => action.bulk && selectedRows.every((row) => row.actions.includes(action.handle)),
  )
})
</script>

<template>
  <div class="space-y-4">
    <PresetTabs
      v-if="listing.presets.length"
      :handle="listing.preference_key"
      :presets="listing.presets"
      :current-query="currentQuery"
    />

    <div class="flex flex-wrap items-center gap-3">
      <ListingSearch v-if="listing.search.enabled" v-model="state.q.value" :placeholder="listing.search.placeholder" />
      <ListingFilters :filters="listing.filters" @change="state.setFilter" />
      <div class="flex-1" />
      <slot name="toolbar-extra" />
      <Button v-if="exportable" variant="outline" size="icon" aria-label="Export CSV" as-child>
        <a :href="exportUrl" download><Download /></a>
      </Button>
      <ColumnPicker :columns="listing.columns" @change="state.setColumns" />
    </div>

    <div
      class="relative mb-8 w-full rounded-2xl bg-gray-150 p-1.75 max-[600px]:p-1.25 dark:bg-gray-950/35 dark:inset-shadow-2xs dark:inset-shadow-black"
    >
      <ListingTable
        :columns="visibleColumns"
        :rows="listing.rows"
        :actions="listing.actions"
        :sort-column="listing.sort.column"
        :sort-direction="listing.sort.direction"
        :selected="state.selected.value"
        @update:selected="(s) => (state.selected.value = s)"
        @sort="state.setSort"
        @action="runAction"
        @row-click="(row) => emit('row-click', row)"
      >
        <template
          v-for="name in Object.keys($slots).filter((n) => n.startsWith('cell-'))"
          :key="name"
          #[name]="slotProps"
          ><slot :name="name" v-bind="slotProps"
        /></template>
      </ListingTable>

      <ListingPagination
        :page="listing.pagination.page"
        :per-page="listing.pagination.per_page"
        :total="listing.pagination.total"
        :pages="listing.pagination.pages"
        :per-page-options="listing.pagination.per_page_options"
        @page="state.setPage"
        @per-page="state.setPerPage"
      />
    </div>

    <BulkActionsBar
      :count="state.selected.value.size"
      :actions="bulkActions"
      @run="(action) => runAction(action, [...state.selected.value])"
      @clear="state.clearSelection"
    />
  </div>
</template>
