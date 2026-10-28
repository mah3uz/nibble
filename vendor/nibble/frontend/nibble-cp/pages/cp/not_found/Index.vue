<script setup lang="ts">
import { router } from '@inertiajs/vue3'
import { FileSearch } from '@lucide/vue'
import CpListing from '@/components/cp/listing/CpListing.vue'
import type { ListingProps } from '@/components/cp/listing/types'
import EmptyState from '@/components/cp/page/EmptyState.vue'
import PageHeader from '@/components/cp/page/PageHeader.vue'
import { Button } from '@/components/ui/button'

defineProps<{ listing: ListingProps; empty: boolean }>()

const suggest = (path: string) => router.visit(`/cp/redirects?from=${encodeURIComponent(path)}`)
</script>

<template>
  <div class="space-y-6">
    <PageHeader title="Missing pages" :breadcrumbs="[{ label: 'Missing pages' }]" />
    <EmptyState
      v-if="empty"
      :icon="FileSearch"
      title="No 404s recorded"
      description="Paths visitors ask for that don't exist show up here."
    />
    <CpListing v-else :listing="listing" :exportable="false">
      <template #cell-path="{ value }">
        <span class="font-mono">{{ value }}</span>
      </template>
      <template #cell-controls="{ row }">
        <div class="flex justify-end gap-2">
          <Button variant="outline" size="sm" @click="suggest(row.path as string)">Add redirect</Button>
          <Button variant="ghost" size="sm" @click="router.delete(`/cp/404s/${row.id}`)">Dismiss</Button>
        </div>
      </template>
    </CpListing>
  </div>
</template>
