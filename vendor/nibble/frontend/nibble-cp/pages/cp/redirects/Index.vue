<script setup lang="ts">
import { router, useForm } from '@inertiajs/vue3'
import { Signpost } from '@lucide/vue'
import { onMounted, ref } from 'vue'
import CpListing from '@/components/cp/listing/CpListing.vue'
import type { ListingProps, ListingRow } from '@/components/cp/listing/types'
import EmptyState from '@/components/cp/page/EmptyState.vue'
import PageHeader from '@/components/cp/page/PageHeader.vue'
import LinkUrlInput from '@/components/LinkUrlInput.vue'
import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from '@/components/ui/dialog'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select'
import { useBreadcrumbs } from '@/lib/breadcrumbs'
import { formatLocale, timeAgo } from '@/lib/format'

const props = defineProps<{ listing: ListingProps; statuses: { value: number; label: string }[] }>()

const SOURCES: Record<string, string> = { manual: 'Manual', auto: 'Automatic', import: 'Imported' }

const open = ref(false)
const editingId = ref<number | null>(null)
const mounted = ref(false)
const form = useForm({ from: '', to: '', status: 301 })

function add(from = '') {
  editingId.value = null
  form.defaults({ from, to: '', status: 301 })
  form.reset()
  form.clearErrors()
  open.value = true
}

function edit(row: ListingRow) {
  editingId.value = row.id
  form.defaults({ from: row.from as string, to: row.to as string, status: row.status_code as number })
  form.reset()
  form.clearErrors()
  open.value = true
}

function save() {
  const options = { preserveScroll: true, onSuccess: () => (open.value = false) }
  const payload = form.transform((data) => ({ redirect: data }))
  if (editingId.value) payload.patch(`/cp/redirects/${editingId.value}`, options)
  else payload.post('/cp/redirects', options)
}

onMounted(() => {
  mounted.value = true
  const url = new URL(window.location.href)
  const from = url.searchParams.get('from')
  if (from === null) return
  url.searchParams.delete('from')
  router.replace({ url: url.pathname + url.search, preserveState: true, preserveScroll: true })
  add(from)
})

useBreadcrumbs([{ label: 'Redirects' }])
</script>

<template>
  <div>
    <PageHeader title="Redirects" icon="arrow-roadmap-path-flow">
      <template #actions>
        <Button @click="add()">Add redirect</Button>
      </template>
    </PageHeader>

    <EmptyState
      v-if="!props.listing.pagination.total && !props.listing.search.value"
      :icon="Signpost"
      title="No redirects yet"
      description="Changing a page's URL adds one automatically."
    />

    <CpListing v-else :listing="listing" :exportable="false" @row-click="edit">
      <template #cell-from="{ row }">
        <button
          type="button"
          class="block max-w-[clamp(10rem,calc(50vw-28rem),18rem)] truncate text-left font-medium hover:underline"
          :title="row.from as string"
          @click="edit(row)"
        >
          {{ row.from }}
        </button>
      </template>
      <template #cell-to="{ value }">
        <span class="block max-w-[clamp(10rem,calc(50vw-28rem),18rem)] truncate" :title="value as string">{{
          value
        }}</span>
      </template>
      <template #cell-status="{ value }">
        <span class="whitespace-nowrap">{{ value }}</span>
      </template>
      <template #cell-source="{ value }">
        <Badge variant="secondary">{{ SOURCES[value as string] ?? value }}</Badge>
      </template>
      <template #cell-hits="{ value }">
        <span class="text-gray-600 tabular-nums dark:text-gray-400">{{
          (value as number).toLocaleString(formatLocale())
        }}</span>
      </template>
      <template #cell-last_hit_at="{ value }">
        <time
          v-if="value && mounted"
          :datetime="value as string"
          :title="new Date(value as string).toLocaleString(formatLocale())"
          class="whitespace-nowrap text-gray-600 dark:text-gray-400"
          >{{ timeAgo(value as string) }}</time
        >
        <span v-else-if="!value" class="text-gray-500">Never</span>
      </template>
    </CpListing>

    <Dialog v-model:open="open">
      <DialogContent>
        <DialogHeader>
          <DialogTitle>{{ editingId ? 'Edit redirect' : 'Add redirect' }}</DialogTitle>
          <DialogDescription>Visitors who ask for the old address are sent to the new one.</DialogDescription>
        </DialogHeader>
        <form id="redirect-form" class="space-y-4" @submit.prevent="save">
          <div class="space-y-1.5">
            <Label for="redirect-from">From</Label>
            <Input
              id="redirect-from"
              v-model="form.from"
              placeholder="/old-page"
              autocomplete="off"
              aria-describedby="redirect-from-help"
              :aria-invalid="!!form.errors.from"
            />
            <p v-if="form.errors.from" class="text-sm text-red-600">{{ form.errors.from }}</p>
            <p id="redirect-from-help" class="text-sm text-gray-600 dark:text-gray-400">
              A path on this site, like <code>/old-page</code>. End it with <code>/*</code> to redirect everything under
              it.
            </p>
          </div>
          <div class="space-y-1.5">
            <Label for="redirect-to">To</Label>
            <LinkUrlInput
              id="redirect-to"
              v-model="form.to"
              aria-describedby="redirect-to-help"
              :aria-invalid="!!form.errors.to"
              @submit="save"
            />
            <p v-if="form.errors.to" class="text-sm text-red-600">{{ form.errors.to }}</p>
            <p id="redirect-to-help" class="text-sm text-gray-600 dark:text-gray-400">
              A path on this site, or a full URL starting with <code>https://</code>.
            </p>
          </div>
          <div class="space-y-1.5">
            <Label for="redirect-status">Status</Label>
            <Select v-model="form.status">
              <SelectTrigger id="redirect-status" class="w-full"><SelectValue /></SelectTrigger>
              <SelectContent>
                <SelectItem v-for="status in statuses" :key="status.value" :value="status.value">
                  {{ status.label }}
                </SelectItem>
              </SelectContent>
            </Select>
            <p v-if="form.errors.status" class="text-sm text-red-600">{{ form.errors.status }}</p>
          </div>
        </form>
        <DialogFooter show-close-button>
          <Button type="submit" form="redirect-form" :disabled="form.processing">
            {{ editingId ? 'Save' : 'Add redirect' }}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  </div>
</template>
