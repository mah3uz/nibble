<script setup lang="ts">
import { Link, router } from '@inertiajs/vue3'
import { computed } from 'vue'
import CpIcon from '@/components/cp/icons/CpIcon.vue'
import DataTablePanel from '@/components/cp/page/DataTablePanel.vue'
import PageHeader from '@/components/cp/page/PageHeader.vue'

type Row = {
  handle: string
  title: string
  parent: string
  icon: string | null
  group: 'Collections' | 'Taxonomies'
  count: number
}

const props = defineProps<{ rows: Row[] }>()

const GROUPS = [
  { label: 'Collections', parent: 'Collection', icon: 'collections' },
  { label: 'Taxonomies', parent: 'Taxonomy', icon: 'taxonomies' },
] as const

const groups = computed(() =>
  GROUPS.map((group) => ({ ...group, rows: props.rows.filter((row) => row.group === group.label) })).filter(
    (group) => group.rows.length,
  ),
)
const url = (row: Row) => `/cp/blueprints/${row.handle}`
</script>

<template>
  <div class="mx-auto max-w-5xl">
    <PageHeader title="Blueprints" icon="blueprints" :breadcrumbs="[{ label: 'Blueprints' }]" />
    <DataTablePanel v-for="group in groups" :key="group.label" :title="group.label">
      <thead>
        <tr>
          <th>Blueprint</th>
          <th class="w-32">In use</th>
          <th class="w-48 text-end!">{{ group.parent }}</th>
        </tr>
      </thead>
      <tbody>
        <tr v-for="row in group.rows" :key="row.handle" class="cursor-pointer" @click="router.visit(url(row))">
          <td>
            <span class="flex items-center gap-3">
              <CpIcon :name="row.icon ?? group.icon" class="size-4 text-gray-500" />
              <Link :href="url(row)" class="hover:underline">{{ row.title }}</Link>
            </span>
          </td>
          <td class="text-sm text-gray-600 dark:text-gray-400">{{ row.count }}</td>
          <td class="text-end font-mono text-xs text-gray-600 dark:text-gray-400">{{ row.parent }}</td>
        </tr>
      </tbody>
    </DataTablePanel>
  </div>
</template>
