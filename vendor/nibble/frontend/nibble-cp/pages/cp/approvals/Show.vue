<script setup lang="ts">
import { useForm } from '@inertiajs/vue3'
import { computed } from 'vue'
import CpPanel from '@/components/cp/page/CpPanel.vue'
import PageHeader from '@/components/cp/page/PageHeader.vue'
import { Alert, AlertDescription } from '@/components/ui/alert'
import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import { useBreadcrumbs } from '@/lib/breadcrumbs'

type Change = { field: string; before: unknown; after: unknown }

const props = defineProps<{
  id: string
  status: 'pending' | 'approved' | 'denied' | 'used' | 'expired'
  app: string
  operation: { title: string | null; description: string | null }
  summary: Record<string, string | null>
  changes: Change[]
  input: Record<string, unknown>
  other_sites: string[]
  expires_at: string
}>()

const form = useForm({ decision: '' })
const open = computed(() => props.status === 'pending')
const show = (value: unknown) =>
  value === null || value === undefined ? '—' : typeof value === 'string' ? value : JSON.stringify(value, null, 2)

function decide(decision: 'approve' | 'deny') {
  form.decision = decision
  form.patch(`/cp/approvals/${props.id}`, { preserveScroll: true })
}

useBreadcrumbs([{ label: 'Connected apps', url: '/cp/account/apps' }, { label: 'Approval' }])
</script>

<template>
  <div class="mx-auto max-w-4xl">
    <PageHeader :title="`${app} asks to: ${operation.title ?? 'make a change'}`">
      <template #meta>
        <Badge variant="secondary">{{ status }}</Badge>
      </template>
      <template v-if="open" #actions>
        <Button variant="outline" :disabled="form.processing" @click="decide('deny')">Decline</Button>
        <Button :disabled="form.processing" @click="decide('approve')">Approve</Button>
      </template>
    </PageHeader>

    <Alert v-if="other_sites.length" class="mb-6">
      <AlertDescription>
        This change links to other sites: {{ other_sites.join(', ') }}. Approve only if you expected them.
      </AlertDescription>
    </Alert>

    <CpPanel title="What happens" :description="operation.description ?? undefined">
      <dl class="grid gap-2 rounded-xl bg-white p-5 text-sm shadow-ui-sm sm:grid-cols-[10rem_1fr] dark:bg-gray-900">
        <template v-for="(value, key) in summary" :key="key">
          <dt class="text-gray-600 dark:text-gray-400">{{ key }}</dt>
          <dd class="break-all">
            <a v-if="key === 'url' && value" :href="value" target="_blank" rel="noopener" class="underline">{{
              value
            }}</a>
            <span v-else>{{ value ?? '—' }}</span>
          </dd>
        </template>
        <template v-for="(value, key) in input" :key="key">
          <dt class="text-gray-600 dark:text-gray-400">{{ key }}</dt>
          <dd class="break-all">{{ show(value) }}</dd>
        </template>
      </dl>
    </CpPanel>

    <CpPanel v-if="changes.length" title="What changes">
      <div class="space-y-3 rounded-xl bg-white p-5 shadow-ui-sm dark:bg-gray-900">
        <div v-for="change in changes" :key="change.field" class="grid gap-2 text-sm sm:grid-cols-[10rem_1fr_1fr]">
          <p class="font-medium">{{ change.field }}</p>
          <pre class="overflow-x-auto rounded-lg bg-red-50 p-2 text-xs whitespace-pre-wrap dark:bg-red-500/10">{{
            show(change.before)
          }}</pre>
          <pre class="overflow-x-auto rounded-lg bg-green-50 p-2 text-xs whitespace-pre-wrap dark:bg-green-500/10">{{
            show(change.after)
          }}</pre>
        </div>
      </div>
    </CpPanel>

    <p class="text-sm text-gray-600 dark:text-gray-400">
      <template v-if="open"
        >Approving lets {{ app }} make exactly this change, once, until
        {{ new Date(expires_at).toLocaleString() }}.</template
      >
      <template v-else-if="status === 'approved'">Approved. {{ app }} can now make this change.</template>
      <template v-else-if="status === 'used'">Done: {{ app }} made this change.</template>
      <template v-else>Nothing will happen.</template>
    </p>
  </div>
</template>
