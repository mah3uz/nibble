<script setup lang="ts">
import { router } from '@inertiajs/vue3'
import { FileSearch } from '@lucide/vue'
import EmptyState from '@/components/admin/page/EmptyState.vue'
import PageHeader from '@/components/admin/page/PageHeader.vue'
import { Button } from '@/components/ui/button'

type Missing = { id: number; path: string; hits: number; referrer: string | null; last_seen_at: string }

defineProps<{ paths: Missing[] }>()

const when = (iso: string) => new Date(iso).toLocaleString('en-AU', { dateStyle: 'medium', timeStyle: 'short' })
const suggest = (row: Missing) => router.visit(`/admin/redirects?from=${encodeURIComponent(row.path)}`)
</script>

<template>
  <div class="space-y-6">
    <PageHeader title="Missing pages" :breadcrumbs="[{ label: 'Missing pages' }]" />
    <EmptyState
      v-if="!paths.length"
      :icon="FileSearch"
      title="No 404s recorded"
      description="Paths visitors ask for that don't exist show up here."
    />
    <table v-else class="w-full text-sm">
      <thead class="text-left text-xs text-muted-foreground">
        <tr>
          <th class="py-2">Path</th>
          <th>Hits</th>
          <th>Last seen</th>
          <th></th>
        </tr>
      </thead>
      <tbody class="divide-y">
        <tr v-for="row in paths" :key="row.id">
          <td class="py-2 font-mono">{{ row.path }}</td>
          <td>{{ row.hits }}</td>
          <td>{{ when(row.last_seen_at) }}</td>
          <td class="text-right">
            <Button variant="outline" size="sm" @click="suggest(row)">Add redirect</Button>
            <Button variant="ghost" size="sm" @click="router.delete(`/admin/404s/${row.id}`)">Dismiss</Button>
          </td>
        </tr>
      </tbody>
    </table>
  </div>
</template>
