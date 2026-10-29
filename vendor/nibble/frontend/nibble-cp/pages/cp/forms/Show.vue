<script setup lang="ts">
import { Link, router } from '@inertiajs/vue3'
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
import { formatDateTime } from '@/lib/format'

const props = defineProps<{
  form: { handle: string; title: string; store: boolean; spam: number; can_export: boolean }
  listing: ListingProps
}>()

const status = computed(() => props.listing.filters.find((filter) => filter.handle === 'status')?.value ?? null)
const tabs = computed(() => [
  { label: 'All but spam', url: `/cp/forms/${props.form.handle}`, active: !status.value },
  {
    label: `Spam (${props.form.spam})`,
    url: `/cp/forms/${props.form.handle}?status=spam`,
    active: status.value === 'spam',
  },
])

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
        <Button v-if="form.can_export" variant="outline" @click="openExport">Export submissions</Button>
      </template>
    </PageHeader>

    <p v-if="!form.store" class="text-sm text-gray-600 dark:text-gray-400">
      This form doesn't store submissions. They're only delivered and emailed.
    </p>

    <div
      v-if="form.store"
      class="-mb-2 flex flex-wrap items-center gap-x-4 border-b border-gray-200 text-sm text-gray-500 dark:border-gray-700"
    >
      <Link
        v-for="tab in tabs"
        :key="tab.label"
        :href="tab.url"
        :aria-current="tab.active ? 'page' : undefined"
        :class="[
          'relative translate-y-px px-2 py-1 hover:text-gray-600 dark:hover:text-gray-400',
          tab.active &&
            'text-gray-900 after:absolute after:inset-x-0 after:bottom-0 after:h-px after:bg-black dark:text-gray-200 dark:after:bg-white',
        ]"
        >{{ tab.label }}</Link
      >
    </div>

    <CpListing :listing="listing" :exportable="false" @row-click="open">
      <template #cell-created_at="{ row, value }">
        <span :class="row.unread ? 'font-semibold' : ''">{{ formatDateTime(value as string) }}</span>
        <span v-if="row.handled" class="ms-2 text-xs text-gray-500">Handled</span>
      </template>
    </CpListing>

    <Dialog v-model:open="exporting">
      <DialogContent>
        <DialogHeader>
          <DialogTitle>Export submissions</DialogTitle>
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
              <input v-model="scope" type="radio" value="all" /> All but spam
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
