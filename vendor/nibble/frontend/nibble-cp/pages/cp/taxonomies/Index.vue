<script setup lang="ts">
import { Link, router } from '@inertiajs/vue3'
import CpListing from '@/components/cp/listing/CpListing.vue'
import type { ListingProps, ListingRow } from '@/components/cp/listing/types'
import PageHeader from '@/components/cp/page/PageHeader.vue'
import { Button } from '@/components/ui/button'

const props = defineProps<{ taxonomy: { handle: string; title: string }; listing: ListingProps }>()

function open(row: ListingRow) {
  if (row.edit_url) router.visit(row.edit_url)
}
</script>

<template>
  <div class="space-y-6">
    <PageHeader :title="taxonomy.title" icon="taxonomies" :breadcrumbs="[{ label: taxonomy.title }]">
      <template #actions>
        <Button v-if="listing.create" as-child>
          <Link :href="listing.create.url">{{ listing.create.label }}</Link>
        </Button>
      </template>
    </PageHeader>
    <CpListing :listing="props.listing" @row-click="open" />
  </div>
</template>
