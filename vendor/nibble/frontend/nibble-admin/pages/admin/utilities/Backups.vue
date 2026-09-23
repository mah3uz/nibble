<script setup lang="ts">
import AdminPanel from '@/components/admin/page/AdminPanel.vue'
import PanelFact from '@/components/admin/page/PanelFact.vue'
import PageHeader from '@/components/admin/page/PageHeader.vue'
import { useBreadcrumbs } from '@/lib/breadcrumbs'

defineProps<{
  backups: { configured: boolean; latest: { name: string; created_at: string; size: string } | null }
}>()

const date = (value: string) => new Date(value).toLocaleString(undefined, { dateStyle: 'medium', timeStyle: 'short' })

useBreadcrumbs([{ label: 'Utilities', url: '/admin/utilities' }, { label: 'Backups' }])
</script>

<template>
  <div>
    <PageHeader
      title="Backups"
      icon="backups"
      :breadcrumbs="[{ label: 'Utilities', url: '/admin/utilities' }, { label: 'Backups' }]"
    />

    <div class="mb-6 grid gap-6 md:grid-cols-2">
      <AdminPanel title="Latest backup" fill>
        <template v-if="backups.latest">
          <p class="text-sm text-gray-600 dark:text-gray-400">
            A compacted copy of the database, taken nightly at 3am and kept on this server for seven days.
          </p>
          <div class="flex flex-wrap gap-2 pt-1">
            <PanelFact label="Taken" :value="date(backups.latest.created_at)" />
            <PanelFact label="Size" :value="backups.latest.size" />
            <PanelFact label="File" :value="backups.latest.name" />
          </div>
        </template>
        <p v-else class="text-sm text-gray-600 dark:text-gray-400">
          No backup has been taken on this server yet. The nightly job runs at 3am wherever the job queue runs, which is
          production.
        </p>
      </AdminPanel>

      <AdminPanel title="Off-site copies" fill>
        <p class="text-sm text-gray-600 dark:text-gray-400">
          {{
            backups.configured
              ? 'Each nightly backup is also uploaded to S3, so the database survives losing this server.'
              : 'Backups stay on this server only. Set DB_SNAPSHOT_BUCKET to keep a copy in S3 as well.'
          }}
        </p>
        <div class="flex flex-wrap gap-2 pt-1">
          <PanelFact label="S3" :value="backups.configured ? 'Configured' : 'Not configured'" />
        </div>
      </AdminPanel>
    </div>

    <p class="text-sm text-gray-600 dark:text-gray-400">
      Restoring one, and what to check afterwards: <code class="text-xs">docs/runbooks/restore.md</code>.
    </p>
  </div>
</template>
