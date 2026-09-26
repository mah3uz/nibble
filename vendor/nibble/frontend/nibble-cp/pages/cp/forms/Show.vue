<script setup lang="ts">
import { router } from '@inertiajs/vue3'
import { computed, ref } from 'vue'
import CpListing from '@/components/cp/listing/CpListing.vue'
import type { ListingProps, ListingRow } from '@/components/cp/listing/types'
import PageHeader from '@/components/cp/page/PageHeader.vue'
import { Button } from '@/components/ui/button'
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from '@/components/ui/dialog'

const props = defineProps<{
  form: { handle: string; title: string; store: boolean; can_export: boolean }
  listing: ListingProps
}>()

const exporting = ref(false)
const scope = ref<'all' | 'filtered'>('all')

const hasFilteredScope = computed(
  () =>
    !!props.listing.search.value ||
    props.listing.filters.some((filter) => filter.value && filter.value.length) ||
    props.listing.sort.direction !== 'desc',
)

function openExport() {
  scope.value = 'all'
  exporting.value = true
}

function exportSubmissions() {
  const query = scope.value === 'filtered' ? window.location.search : ''
  window.open(`/cp/forms/${props.form.handle}.csv${query}`, '_blank')
  exporting.value = false
}

function open(row: ListingRow) {
  if (row.edit_url) router.visit(row.edit_url)
}
</script>

<template>
  <div class="mx-auto max-w-5xl space-y-6">
    <PageHeader
      :title="form.title"
      icon="forms"
      :breadcrumbs="[{ label: 'Forms', url: '/cp/forms' }, { label: form.title }]"
    >
      <template #actions>
        <Button v-if="form.can_export" variant="outline" @click="openExport">Export Submissions</Button>
      </template>
    </PageHeader>

    <p v-if="!form.store" class="text-sm text-gray-600 dark:text-gray-400">
      This form doesn't store submissions. They're only delivered and emailed.
    </p>

    <CpListing :listing="listing" :exportable="false" @row-click="open">
      <template #cell-created_at="{ row, value }">
        <span :class="row.unread ? 'font-semibold' : ''">{{
          new Date(value as string).toLocaleString(undefined, { dateStyle: 'medium', timeStyle: 'short' })
        }}</span>
      </template>
    </CpListing>

    <Dialog v-model:open="exporting">
      <DialogContent>
        <DialogHeader>
          <DialogTitle>Export Submissions</DialogTitle>
          <DialogDescription class="sr-only">Download this form's submissions as a file.</DialogDescription>
        </DialogHeader>
        <div class="space-y-4">
          <div>
            <span class="mb-1.5 block text-sm font-medium">Format</span>
            <label class="flex items-center gap-2 text-sm"><input type="radio" checked /> CSV</label>
          </div>
          <fieldset>
            <legend class="mb-1.5 block text-sm font-medium">Submissions</legend>
            <label class="flex items-center gap-2 text-sm">
              <input v-model="scope" type="radio" value="all" /> All submissions
            </label>
            <label class="mt-2 flex items-start gap-2 text-sm" :class="{ 'opacity-50': !hasFilteredScope }">
              <input v-model="scope" type="radio" value="filtered" :disabled="!hasFilteredScope" class="mt-1" />
              <span>
                Filtered submissions
                <span class="block text-gray-600 dark:text-gray-400"
                  >Only the submissions matching the current search and filters.</span
                >
              </span>
            </label>
          </fieldset>
        </div>
        <DialogFooter>
          <Button @click="exportSubmissions">Export</Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  </div>
</template>
