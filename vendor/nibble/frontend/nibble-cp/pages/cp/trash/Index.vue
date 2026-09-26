<script setup lang="ts">
import { router } from '@inertiajs/vue3'
import CpIcon from '@/components/cp/icons/CpIcon.vue'
import DataTablePanel from '@/components/cp/page/DataTablePanel.vue'
import PageHeader from '@/components/cp/page/PageHeader.vue'
import { Button } from '@/components/ui/button'
import { useBreadcrumbs } from '@/lib/breadcrumbs'
import { useConfirm } from '@/lib/confirm'

type TrashItem = {
  id: string
  type: string
  group: string
  title: string | null
  uri: string | null
  deleted_at: string
  referrers: number
}

defineProps<{ items: TrashItem[] }>()
const confirm = useConfirm()
useBreadcrumbs([{ label: 'Trash' }])

const when = (iso: string) => new Date(iso).toLocaleString('en-AU', { dateStyle: 'medium', timeStyle: 'short' })

async function purge(item: TrashItem) {
  const ok = await confirm({
    title: `Delete "${item.title ?? 'Untitled'}" for good?`,
    description: 'This cannot be undone.',
    confirmText: 'Delete for good',
    dangerous: true,
  })
  if (ok) router.delete(`/cp/trash/${item.id}/purge`)
}
</script>

<template>
  <div class="mx-auto max-w-5xl">
    <div v-if="!items.length" class="mx-auto max-w-md py-14">
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
      <DataTablePanel>
        <thead>
          <tr>
            <th>Title</th>
            <th>Type</th>
            <th>Deleted</th>
            <th class="actions-column" />
          </tr>
        </thead>
        <tbody>
          <tr v-for="item in items" :key="item.id">
            <td>
              <span class="font-medium">{{ item.title ?? 'Untitled' }}</span>
              <span v-if="item.referrers" class="block text-xs text-amber-700 dark:text-amber-400">
                Referenced by {{ item.referrers }} other {{ item.referrers === 1 ? 'record' : 'records' }}
              </span>
            </td>
            <td class="text-sm text-gray-600 capitalize dark:text-gray-400">{{ item.group }}</td>
            <td class="text-sm text-gray-600 dark:text-gray-400">{{ when(item.deleted_at) }}</td>
            <td class="actions-column">
              <div class="flex justify-end gap-2">
                <Button variant="outline" size="sm" @click="router.post(`/cp/trash/${item.id}/restore`)">
                  Restore
                </Button>
                <Button variant="ghost" size="sm" class="text-destructive" @click="purge(item)">Delete</Button>
              </div>
            </td>
          </tr>
        </tbody>
      </DataTablePanel>
    </template>
  </div>
</template>
