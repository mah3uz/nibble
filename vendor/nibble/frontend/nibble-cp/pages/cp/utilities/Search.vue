<script setup lang="ts">
import { router } from '@inertiajs/vue3'
import CpIcon from '@/components/cp/icons/CpIcon.vue'
import CpPanel from '@/components/cp/page/CpPanel.vue'
import PanelFact from '@/components/cp/page/PanelFact.vue'
import PageHeader from '@/components/cp/page/PageHeader.vue'
import { Button } from '@/components/ui/button'
import { useBreadcrumbs } from '@/lib/breadcrumbs'

type Index = { handle: string; collections: string[]; taxonomies: string[]; fields: string[] }

defineProps<{ search: { indexes: Index[]; indexed: number; total: number; can_rebuild: boolean } }>()

const rebuild = () => router.post('/cp/utilities/rebuild_search', {}, { preserveScroll: true })

useBreadcrumbs([{ label: 'Utilities', url: '/cp/utilities' }, { label: 'Search' }])
</script>

<template>
  <div>
    <PageHeader
      title="Search"
      icon="search-magnifying-glass"
      :breadcrumbs="[{ label: 'Utilities', url: '/cp/utilities' }, { label: 'Search' }]"
    >
      <template #actions><Button v-if="search.can_rebuild" @click="rebuild">Rebuild indexes</Button></template>
    </PageHeader>

    <CpPanel title="Search indexes" flush>
      <template #actions>
        <PanelFact label="Documents" :value="search.indexed" />
        <PanelFact label="Live entries covered" :value="search.total" />
      </template>
      <table class="w-full text-sm">
        <thead>
          <tr class="border-b border-gray-200 text-start dark:border-gray-700">
            <th class="px-4.5 py-3 text-start font-medium">Index</th>
            <th class="px-4.5 py-3 text-start font-medium">Covers</th>
            <th class="px-4.5 py-3 text-start font-medium">Fields</th>
          </tr>
        </thead>
        <tbody>
          <tr
            v-for="index in search.indexes"
            :key="index.handle"
            class="border-b border-gray-100 last:border-0 dark:border-gray-800"
          >
            <td class="px-4.5 py-3">
              <span class="flex items-center gap-2.5">
                <span class="grid size-6 place-items-center rounded-md bg-gray-100 dark:bg-gray-800">
                  <CpIcon name="search-magnifying-glass" class="size-3.5 text-gray-500" />
                </span>
                {{ index.handle }}
              </span>
            </td>
            <td class="px-4.5 py-3">
              <span class="flex flex-wrap gap-1.5">
                <span
                  v-for="handle in index.collections"
                  :key="handle"
                  class="rounded-md border border-gray-300 px-2 py-0.5 text-xs dark:border-gray-700"
                  >collection:{{ handle }}</span
                >
                <span
                  v-for="handle in index.taxonomies"
                  :key="handle"
                  class="rounded-md border border-gray-300 px-2 py-0.5 text-xs dark:border-gray-700"
                  >taxonomy:{{ handle }}</span
                >
              </span>
            </td>
            <td class="px-4.5 py-3">
              <span class="flex flex-wrap gap-1.5">
                <span
                  v-for="field in index.fields"
                  :key="field"
                  class="rounded-md border border-gray-300 px-2 py-0.5 text-xs dark:border-gray-700"
                  >{{ field }}</span
                >
              </span>
            </td>
          </tr>
        </tbody>
      </table>
      <p v-if="!search.indexes.length" class="px-4.5 py-4 text-gray-500">This site defines no search indexes.</p>
    </CpPanel>
  </div>
</template>
