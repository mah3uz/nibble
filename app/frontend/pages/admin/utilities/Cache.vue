<script setup lang="ts">
import { router, useForm } from '@inertiajs/vue3'
import AdminPanel from '@/components/admin/page/AdminPanel.vue'
import PanelFact from '@/components/admin/page/PanelFact.vue'
import PageHeader from '@/components/admin/page/PageHeader.vue'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { useBreadcrumbs } from '@/lib/breadcrumbs'

defineProps<{ store: string }>()

const form = useForm({ tags: '' })
const clearAll = () => router.post('/admin/utilities/clear_cache', {}, { preserveScroll: true })
const purge = () => form.post('/admin/utilities/purge_cache', { preserveScroll: true, onSuccess: () => form.reset() })

useBreadcrumbs([{ label: 'Utilities', url: '/admin/utilities' }, { label: 'Cache' }])
</script>

<template>
  <div>
    <PageHeader
      title="Cache"
      icon="cache"
      :breadcrumbs="[{ label: 'Utilities', url: '/admin/utilities' }, { label: 'Cache' }]"
    >
      <template #actions><Button @click="clearAll">Clear all pages</Button></template>
    </PageHeader>

    <div class="mb-6 grid gap-6 md:grid-cols-2">
      <AdminPanel title="Page cache" fill>
        <template #actions><Button variant="outline" size="sm" @click="clearAll">Clear</Button></template>
        <p class="text-sm text-gray-600 dark:text-gray-400">
          Public pages are kept whole after their first visit. Each is tagged with the records it shows, so a change
          clears only the pages it touches, and the rest stay fast.
        </p>
        <div class="flex flex-wrap gap-2 pt-1"><PanelFact label="Store" :value="store" /></div>
      </AdminPanel>

      <AdminPanel title="Clear by tag" fill>
        <p class="text-sm text-gray-600 dark:text-gray-400">
          Clear only the pages that show certain records, such as <code class="text-xs">entry:12</code> or
          <code class="text-xs">collection:posts</code>.
        </p>
        <form class="flex gap-2 pt-1" @submit.prevent="purge">
          <Label for="cache-tags" class="sr-only">Tags</Label>
          <Input id="cache-tags" v-model="form.tags" placeholder="entry:12, collection:posts" />
          <Button type="submit" variant="outline" :disabled="!form.tags.trim() || form.processing">Clear</Button>
        </form>
      </AdminPanel>
    </div>
  </div>
</template>
