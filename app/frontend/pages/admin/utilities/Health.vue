<script setup lang="ts">
import { router } from '@inertiajs/vue3'
import StatusCell from '@/components/admin/listing/cells/StatusCell.vue'
import AdminPanel from '@/components/admin/page/AdminPanel.vue'
import PanelFact from '@/components/admin/page/PanelFact.vue'
import PageHeader from '@/components/admin/page/PageHeader.vue'
import { Button } from '@/components/ui/button'
import { useBreadcrumbs } from '@/lib/breadcrumbs'

type Check = { name: string; status: 'ok' | 'warn' | 'fail' | 'skip'; message: string; ms: number }

type System = {
  nibble: number
  rails: string
  ruby: string
  environment: string
  entries: number
  terms: number
  trashed: number
  pending_events: number
}

defineProps<{ status: 'ok' | 'degraded' | 'down'; checks: Check[]; checked_at: string; system: System }>()

const LABELS: Record<Check['status'], string> = { ok: 'healthy', warn: 'warning', fail: 'failing', skip: 'skipped' }
const NAMES: Record<string, string> = {
  database: 'Database',
  queue: 'Job queue',
  storage: 'File storage',
  ssr: 'Server rendering',
}
const OVERALL: Record<string, string> = { ok: 'healthy', degraded: 'degraded', down: 'down' }

const time = (value: string) => new Date(value).toLocaleTimeString(undefined, { timeStyle: 'medium' })

useBreadcrumbs([{ label: 'Utilities', url: '/admin/utilities' }, { label: 'Health' }])
</script>

<template>
  <div>
    <PageHeader
      title="Health"
      icon="health"
      :breadcrumbs="[{ label: 'Utilities', url: '/admin/utilities' }, { label: 'Health' }]"
    >
      <template #meta>
        <StatusCell :value="OVERALL[status]" />
      </template>
      <template #actions>
        <Button variant="outline" @click="router.reload()">Check again</Button>
      </template>
    </PageHeader>

    <AdminPanel title="Checks" :description="`Checked at ${time(checked_at)}`" flush>
      <div class="text-sm">
        <div
          v-for="check in checks"
          :key="check.name"
          class="flex items-center gap-4 border-b border-gray-100 px-4.5 py-3 last:border-0 dark:border-gray-800"
        >
          <span class="w-36 shrink-0 font-medium">{{ NAMES[check.name] ?? check.name }}</span>
          <StatusCell :value="LABELS[check.status]" />
          <span class="flex-1 text-gray-600 dark:text-gray-400">{{ check.message }}</span>
          <span class="shrink-0 text-xs text-gray-500 tabular-nums">{{ check.ms }} ms</span>
        </div>
      </div>
    </AdminPanel>

    <AdminPanel title="System">
      <div class="flex flex-wrap gap-2">
        <PanelFact label="Rails" :value="system.rails" />
        <PanelFact label="Ruby" :value="system.ruby" />
        <PanelFact label="Environment" :value="system.environment" />
        <PanelFact label="Entries" :value="system.entries" />
        <PanelFact label="Terms" :value="system.terms" />
        <PanelFact label="In the trash" :value="system.trashed" />
        <PanelFact label="Events waiting" :value="system.pending_events" />
      </div>
    </AdminPanel>

    <p class="text-sm text-gray-600 dark:text-gray-400">
      Uptime monitors can call <code class="text-xs">/api/v1/health</code> with an API token that has the “Check site
      health” scope. It answers 200 while the site is healthy or degraded and 503 when a check fails.
      <code class="text-xs">/up</code> stays the plain “is the app running” check.
    </p>
  </div>
</template>
