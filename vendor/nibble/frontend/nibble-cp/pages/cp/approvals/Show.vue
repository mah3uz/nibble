<script setup lang="ts">
import { formatLocale } from '@/lib/format'
import { Link, useForm } from '@inertiajs/vue3'
import { CircleAlert, CircleCheck } from '@lucide/vue'
import { computed, ref } from 'vue'
import CpPanel from '@/components/cp/page/CpPanel.vue'
import PageHeader from '@/components/cp/page/PageHeader.vue'
import { Alert, AlertDescription, AlertTitle } from '@/components/ui/alert'
import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import { useBreadcrumbs } from '@/lib/breadcrumbs'

type Change = { field: string; label?: string; before: unknown; after: unknown }

const props = defineProps<{
  id: string
  status: 'pending' | 'approved' | 'done' | 'failed' | 'denied' | 'expired'
  app: string
  operation: { title: string | null; description: string | null }
  summary: Record<string, string | null>
  changes: Change[]
  input: Record<string, unknown>
  other_sites: string[]
  expires_at: string
  result: Record<string, unknown> | null
  error: { code: string; message: string; hint?: string } | null
}>()

const form = useForm({ decision: '' })
const open = computed(() => props.status === 'pending')
const STATUS: Record<string, string> = {
  pending: 'Waiting',
  approved: 'Being made',
  done: 'Done',
  failed: "Couldn't be made",
  denied: 'Declined',
  expired: 'Expired',
}
const upload = computed(() => (typeof props.input.upload === 'string' ? props.input.upload : null))
const HIDDEN = ['upload', 'id', 'lock_version', 'idempotency_key', 'dry_run']
const KEY_LABELS: Record<string, string> = {
  title: 'Title',
  status: 'Status',
  url: 'Address',
  collection: 'Collection',
  taxonomy: 'Taxonomy',
  handle: 'Name',
  filename: 'File name',
  action: 'Action',
  locale: 'Language',
}
const keyLabel = (key: string) => KEY_LABELS[key] ?? key.charAt(0).toUpperCase() + key.slice(1).replace(/_/g, ' ')
const details = computed(() => Object.fromEntries(Object.entries(props.input).filter(([key]) => !HIDDEN.includes(key))))
const previewFailed = ref(false)
const outcome = computed(() => {
  const result = props.result
  if (!result) return null
  const text = (key: string) => (typeof result[key] === 'string' ? (result[key] as string) : null)
  return {
    summary: [text('result'), text('title') ?? text('filename') ?? text('handle')].filter(Boolean).join(': '),
    cpUrl: text('cp_url'),
    url: text('url'),
  }
})
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
        <Badge variant="secondary">{{ STATUS[status] ?? status }}</Badge>
      </template>
      <template v-if="open" #actions>
        <Button variant="outline" :disabled="form.processing" @click="decide('deny')">Decline</Button>
        <Button :disabled="form.processing" @click="decide('approve')">Approve</Button>
      </template>
    </PageHeader>

    <Alert v-if="status === 'done'" class="mb-6">
      <CircleCheck />
      <AlertTitle>Approved and done</AlertTitle>
      <AlertDescription>
        <p v-if="outcome?.summary" class="first-letter:uppercase">{{ outcome.summary }}</p>
        <p v-if="outcome?.cpUrl || outcome?.url" class="flex gap-3">
          <Link v-if="outcome.cpUrl" :href="outcome.cpUrl" class="underline">Open it</Link>
          <a v-if="outcome.url" :href="outcome.url" target="_blank" rel="noopener" class="underline"
            >View on the site</a
          >
        </p>
      </AlertDescription>
    </Alert>
    <Alert v-else-if="status === 'failed'" variant="destructive" class="mb-6">
      <CircleAlert />
      <AlertTitle>{{
        error?.code === 'interrupted'
          ? 'Approved, but it may not have been made'
          : "Approved, but the change couldn't be made"
      }}</AlertTitle>
      <AlertDescription>
        <p class="first-letter:uppercase">{{ error?.message }}</p>
        <p v-if="error?.hint">{{ error.hint }}</p>
      </AlertDescription>
    </Alert>

    <Alert v-if="other_sites.length" class="mb-6">
      <AlertDescription>
        This change links to other sites: {{ other_sites.join(', ') }}. Approve only if you expected them.
      </AlertDescription>
    </Alert>

    <CpPanel title="What happens" :description="operation.description ?? undefined">
      <dl class="grid gap-2 rounded-xl bg-white p-5 text-sm shadow-ui-sm sm:grid-cols-[10rem_1fr] dark:bg-gray-900">
        <template v-for="(value, key) in summary" :key="key">
          <dt class="text-gray-600 dark:text-gray-400">{{ keyLabel(String(key)) }}</dt>
          <dd class="break-all">
            <a v-if="key === 'url' && value" :href="value" target="_blank" rel="noopener" class="underline">{{
              value
            }}</a>
            <span v-else>{{ value ?? '—' }}</span>
          </dd>
        </template>
        <template v-if="upload">
          <dt class="text-gray-600 dark:text-gray-400">File</dt>
          <dd>
            <img
              v-if="!previewFailed"
              :src="`/cp/uploads/${upload}/preview`"
              :alt="summary.filename ?? ''"
              class="max-h-48 rounded-lg bg-gray-100 object-contain dark:bg-gray-800"
              @error="previewFailed = true"
            />
            <span v-else>{{ summary.filename ?? 'An uploaded file' }}</span>
          </dd>
        </template>
        <template v-for="(value, key) in details" :key="key">
          <dt class="text-gray-600 dark:text-gray-400">{{ keyLabel(String(key)) }}</dt>
          <dd class="break-all">{{ show(value) }}</dd>
        </template>
      </dl>
    </CpPanel>

    <CpPanel v-if="changes.length" title="What changes">
      <div class="space-y-3 rounded-xl bg-white p-5 shadow-ui-sm dark:bg-gray-900">
        <div v-for="change in changes" :key="change.field" class="grid gap-2 text-sm sm:grid-cols-[10rem_1fr_1fr]">
          <p class="font-medium">{{ change.label ?? change.field }}</p>
          <pre class="overflow-x-auto rounded-lg bg-red-50 p-2 text-xs whitespace-pre-wrap dark:bg-red-500/10">{{
            show(change.before)
          }}</pre>
          <pre class="overflow-x-auto rounded-lg bg-green-50 p-2 text-xs whitespace-pre-wrap dark:bg-green-500/10">{{
            show(change.after)
          }}</pre>
        </div>
      </div>
    </CpPanel>

    <p v-if="!['done', 'failed'].includes(status)" class="text-sm text-gray-600 dark:text-gray-400">
      <template v-if="open"
        >Approving makes exactly this change, once. It can be approved until
        {{ new Date(expires_at).toLocaleString(formatLocale()) }}.</template
      >
      <template v-else-if="status === 'approved'">Approved. The change is being made.</template>
      <template v-else-if="status === 'denied'">Declined. Nothing was changed.</template>
      <template v-else-if="status === 'expired'">Nobody decided in time, so nothing was changed.</template>
    </p>
  </div>
</template>
