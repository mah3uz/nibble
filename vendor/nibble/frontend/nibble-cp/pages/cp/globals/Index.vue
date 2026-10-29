<script setup lang="ts">
import { Link, router } from '@inertiajs/vue3'
import DataTablePanel from '@/components/cp/page/DataTablePanel.vue'
import PageHeader from '@/components/cp/page/PageHeader.vue'

defineProps<{ sets: { handle: string; title: string; url: string }[] }>()
</script>

<template>
  <div class="mx-auto max-w-5xl">
    <PageHeader title="Site settings" icon="globals" :breadcrumbs="[{ label: 'Site settings' }]" />
    <DataTablePanel>
      <thead>
        <tr>
          <th>Name</th>
        </tr>
      </thead>
      <tbody>
        <tr v-for="set in sets" :key="set.handle" class="cursor-pointer" @click="router.visit(set.url)">
          <td>
            <Link :href="set.url" class="hover:underline">{{ set.title }}</Link>
          </td>
        </tr>
      </tbody>
    </DataTablePanel>
  </div>
</template>
