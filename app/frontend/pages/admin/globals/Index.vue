<script setup lang="ts">
import { Link, router } from '@inertiajs/vue3'
import DataTablePanel from '@/components/admin/page/DataTablePanel.vue'
import PageHeader from '@/components/admin/page/PageHeader.vue'

defineProps<{ sets: { handle: string; title: string; url: string }[] }>()
</script>

<template>
  <div class="mx-auto max-w-5xl">
    <PageHeader title="Globals" icon="globals" :breadcrumbs="[{ label: 'Globals' }]" />
    <DataTablePanel>
      <thead>
        <tr>
          <th>Title</th>
          <th class="w-1/2">Handle</th>
        </tr>
      </thead>
      <tbody>
        <tr v-for="set in sets" :key="set.handle" class="cursor-pointer" @click="router.visit(set.url)">
          <td>
            <Link :href="set.url" class="hover:underline">{{ set.title }}</Link>
          </td>
          <td class="font-mono text-xs text-gray-600 dark:text-gray-400">{{ set.handle }}</td>
        </tr>
      </tbody>
    </DataTablePanel>
  </div>
</template>
