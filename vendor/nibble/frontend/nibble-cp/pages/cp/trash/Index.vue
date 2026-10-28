<script setup lang="ts">
import { router } from '@inertiajs/vue3'
import CpIcon from '@/components/cp/icons/CpIcon.vue'
import CpListing from '@/components/cp/listing/CpListing.vue'
import type { ListingProps } from '@/components/cp/listing/types'
import PageHeader from '@/components/cp/page/PageHeader.vue'
import { Button } from '@/components/ui/button'
import { useBreadcrumbs } from '@/lib/breadcrumbs'
import { useConfirm } from '@/lib/confirm'

type TrashRow = { key: string; title: string | null; referrers: number }

defineProps<{ listing: ListingProps; empty: boolean }>()
const confirm = useConfirm()
useBreadcrumbs([{ label: 'Trash' }])

async function purge(row: TrashRow) {
  const ok = await confirm({
    title: `Delete "${row.title ?? 'Untitled'}" for good?`,
    description: 'This cannot be undone.',
    confirmText: 'Delete for good',
    dangerous: true,
  })
  if (ok) router.delete(`/cp/trash/${row.key}/purge`)
}
</script>

<template>
  <div class="mx-auto max-w-5xl">
    <div v-if="empty" class="mx-auto max-w-md py-14">
      <h1 class="mb-8 flex items-center justify-center gap-3 text-[25px] font-medium">
        <CpIcon name="trash" class="size-5 text-gray-500" />Trash
      </h1>
      <div class="rounded-2xl bg-gray-150 p-1.5 dark:bg-gray-950/35">
        <p class="rounded-xl bg-white p-5 text-sm shadow-ui-sm dark:bg-gray-900">
          The trash is empty. Deleted entries, terms and assets wait here, where they can be restored or deleted for
          good.
        </p>
      </div>
    </div>

    <template v-else>
      <PageHeader title="Trash" icon="trash" />
      <CpListing :listing="listing" :exportable="false">
        <template #cell-title="{ row }">
          <span class="font-medium">{{ (row.title as string | null) ?? 'Untitled' }}</span>
          <span v-if="row.referrers" class="block text-xs text-amber-700 dark:text-amber-400">
            Referenced by {{ row.referrers }} other {{ row.referrers === 1 ? 'record' : 'records' }}
          </span>
        </template>
        <template #cell-group="{ value }">
          <span class="text-sm text-gray-600 capitalize dark:text-gray-400">{{ value }}</span>
        </template>
        <template #cell-controls="{ row }">
          <div class="flex justify-end gap-2">
            <Button variant="outline" size="sm" @click="router.post(`/cp/trash/${row.key}/restore`)">Restore</Button>
            <Button variant="ghost" size="sm" class="text-destructive" @click="purge(row as unknown as TrashRow)">
              Delete
            </Button>
          </div>
        </template>
      </CpListing>
    </template>
  </div>
</template>
