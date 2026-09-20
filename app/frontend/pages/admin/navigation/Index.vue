<script setup lang="ts">
import { Link, router } from '@inertiajs/vue3'
import DataTablePanel from '@/components/admin/page/DataTablePanel.vue'
import PageHeader from '@/components/admin/page/PageHeader.vue'

defineProps<{ menus: { handle: string; title: string; url: string }[] }>()
</script>

<template>
  <div class="mx-auto max-w-5xl">
    <PageHeader title="Navigation" icon="navigation" :breadcrumbs="[{ label: 'Navigation' }]" />
    <DataTablePanel>
      <thead>
        <tr>
          <th>Title</th>
        </tr>
      </thead>
      <tbody>
        <tr v-for="menu in menus" :key="menu.handle" class="cursor-pointer" @click="router.visit(menu.url)">
          <td>
            <Link :href="menu.url" class="hover:underline">{{ menu.title }}</Link>
          </td>
        </tr>
      </tbody>
    </DataTablePanel>
  </div>
</template>
