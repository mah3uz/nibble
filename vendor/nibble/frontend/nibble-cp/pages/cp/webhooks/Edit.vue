<script setup lang="ts">
import { Link, router, useForm } from '@inertiajs/vue3'
import { computed, ref } from 'vue'
import StatusCell from '@/components/cp/listing/cells/StatusCell.vue'
import PageHeader from '@/components/cp/page/PageHeader.vue'
import CpIcon from '@/components/cp/icons/CpIcon.vue'
import { Button } from '@/components/ui/button'
import { Checkbox } from '@/components/ui/checkbox'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Switch } from '@/components/ui/switch'
import { useConfirm } from '@/lib/confirm'

type Option = { value: string; label: string }
type Delivery = {
  id: number
  event: string
  status: string
  attempts: number
  response_status: number | null
  error: string | null
  created_at: string
  next_attempt_at: string | null
  request_body: string | null
  response_body: string | null
  duration_ms: number | null
}

const props = defineProps<{
  webhook: {
    id: number | null
    name: string
    url: string
    events: string[]
    collections: string[]
    enabled: boolean
    secret?: string
    disabled_reason?: string | null
    disabled_at?: string | null
  }
  events: Option[]
  collections: Option[]
  deliveries: Delivery[]
}>()

const confirm = useConfirm()
const base = computed(() => (props.webhook.id ? `/cp/webhooks/${props.webhook.id}` : null))
const title = computed(() => (props.webhook.id ? props.webhook.name : 'Create webhook'))
const revealed = ref(false)
const expanded = ref<number | null>(null)

const form = useForm({
  name: props.webhook.name,
  url: props.webhook.url,
  events: [...props.webhook.events],
  collections: [...props.webhook.collections],
  enabled: props.webhook.enabled,
})

const date = (value: string) => new Date(value).toLocaleString(undefined, { dateStyle: 'medium', timeStyle: 'medium' })

function toggle(list: string[], value: string, on: boolean) {
  const index = list.indexOf(value)
  if (on && index === -1) list.push(value)
  if (!on && index !== -1) list.splice(index, 1)
}

function save() {
  const request = form.transform((data) => ({ webhook: data }))
  if (base.value) request.patch(base.value, { preserveScroll: true })
  else request.post('/cp/webhooks', { preserveState: 'errors' })
}

const post = (path: string) => router.post(`${base.value}/${path}`, {}, { preserveScroll: true })

async function rollSecret() {
  const ok = await confirm({
    title: 'Create a new signing secret?',
    description: 'The current secret stops working immediately. Update your receiver with the new one.',
    confirmText: 'Create new secret',
    dangerous: true,
  })
  if (ok) post('roll_secret')
}

async function destroy() {
  const ok = await confirm({
    title: `Delete ${props.webhook.name}?`,
    description: 'Its delivery history is deleted too.',
    confirmText: 'Delete',
    dangerous: true,
  })
  if (ok) router.delete(base.value!)
}

function copySecret() {
  if (props.webhook.secret) void navigator.clipboard.writeText(props.webhook.secret)
}
</script>

<template>
  <div class="mx-auto max-w-5xl">
    <Link
      href="/cp/webhooks"
      class="relative z-10 -mb-6 flex w-fit items-center gap-1 pt-6 text-sm text-gray-600 hover:text-gray-900 dark:text-gray-400 dark:hover:text-white"
    >
      <CpIcon name="chevron-left" class="size-4" />Webhooks
    </Link>
    <PageHeader
      :title="title"
      icon="webhooks"
      :breadcrumbs="[{ label: 'Webhooks', url: '/cp/webhooks' }, { label: title }]"
    >
      <template v-if="webhook.id" #meta>
        <StatusCell :value="webhook.enabled ? 'enabled' : 'disabled'" />
      </template>
      <template #actions>
        <Button v-if="webhook.id" variant="outline" @click="destroy">Delete</Button>
        <Button v-if="webhook.id" variant="outline" @click="post('test')">Send test</Button>
        <Button :disabled="form.processing" @click="save">{{ webhook.id ? 'Save' : 'Create' }}</Button>
      </template>
    </PageHeader>

    <div
      v-if="webhook.id && !webhook.enabled && webhook.disabled_reason"
      class="mb-6 flex items-center justify-between gap-4 rounded-xl border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-900 dark:border-red-900/50 dark:bg-red-950/30 dark:text-red-200"
    >
      <span>Turned off {{ webhook.disabled_at ? date(webhook.disabled_at) : '' }}: {{ webhook.disabled_reason }}.</span>
      <Button size="sm" variant="outline" @click="post('enable')">Turn back on</Button>
    </div>

    <form
      class="relative mb-6 w-full rounded-2xl bg-gray-150 p-1.75 dark:bg-gray-950/35 dark:inset-shadow-2xs dark:inset-shadow-black"
      @submit.prevent="save"
    >
      <div
        class="space-y-6 rounded-xl bg-white px-4 py-5 shadow-ui-md ring ring-gray-200 sm:px-4.5 dark:bg-gray-850 dark:ring-gray-700/80"
      >
        <div class="grid gap-6 md:grid-cols-2">
          <div class="space-y-1.5">
            <Label for="webhook-name">Name</Label>
            <Input
              id="webhook-name"
              v-model="form.name"
              placeholder="Rebuild the static site"
              :aria-invalid="!!form.errors.name"
            />
            <p v-if="form.errors.name" class="text-sm text-red-600">{{ form.errors.name }}</p>
          </div>
          <div class="space-y-1.5">
            <Label for="webhook-url">URL</Label>
            <Input
              id="webhook-url"
              v-model="form.url"
              type="url"
              placeholder="https://example.com/hooks/nibble"
              :aria-invalid="!!form.errors.url"
            />
            <p v-if="form.errors.url" class="text-sm text-red-600">{{ form.errors.url }}</p>
          </div>
        </div>

        <fieldset class="space-y-2">
          <legend class="mb-1.5 text-sm font-medium">Events</legend>
          <div class="grid gap-2 sm:grid-cols-2 md:grid-cols-3">
            <label v-for="event in events" :key="event.value" class="flex items-center gap-2 text-sm">
              <Checkbox
                :model-value="form.events.includes(event.value)"
                @update:model-value="(on) => toggle(form.events, event.value, !!on)"
              />
              {{ event.label }} <code class="text-xs text-gray-500">{{ event.value }}</code>
            </label>
          </div>
          <p v-if="form.errors.events" class="text-sm text-red-600">{{ form.errors.events }}</p>
        </fieldset>

        <fieldset v-if="collections.length" class="space-y-2">
          <legend class="text-sm font-medium">Collections</legend>
          <p class="text-sm text-gray-600 dark:text-gray-400">
            Leave all unticked to send events for everything. Ticking any sends only entry events from those
            collections.
          </p>
          <div class="flex flex-wrap gap-x-6 gap-y-2">
            <label v-for="collection in collections" :key="collection.value" class="flex items-center gap-2 text-sm">
              <Checkbox
                :model-value="form.collections.includes(collection.value)"
                @update:model-value="(on) => toggle(form.collections, collection.value, !!on)"
              />
              {{ collection.label }}
            </label>
          </div>
          <p v-if="form.errors.collections" class="text-sm text-red-600">{{ form.errors.collections }}</p>
        </fieldset>

        <label class="flex items-center gap-3 text-sm">
          <Switch v-model="form.enabled" />
          Send deliveries
        </label>

        <div v-if="webhook.secret" class="space-y-1.5">
          <Label for="webhook-secret">Signing secret</Label>
          <div class="flex gap-2">
            <Input
              id="webhook-secret"
              :model-value="revealed ? webhook.secret : '•'.repeat(32)"
              readonly
              class="font-mono"
            />
            <Button type="button" variant="outline" @click="revealed = !revealed">{{
              revealed ? 'Hide' : 'Reveal'
            }}</Button>
            <Button type="button" variant="outline" @click="copySecret">Copy</Button>
            <Button type="button" variant="outline" @click="rollSecret">New secret</Button>
          </div>
          <p class="text-sm text-gray-600 dark:text-gray-400">
            Each request carries <code>X-Nibble-Signature: t=&lt;time&gt;,v1=&lt;signature&gt;</code>, an HMAC-SHA256 of
            <code>&lt;time&gt;.&lt;body&gt;</code> with this secret. Reject requests whose signature doesn't match or
            whose time is more than a few minutes old.
          </p>
        </div>
      </div>
    </form>

    <section
      v-if="webhook.id"
      class="relative mb-6 w-full rounded-2xl bg-gray-150 p-1.75 pt-0 dark:bg-gray-950/35 dark:inset-shadow-2xs dark:inset-shadow-black"
    >
      <header class="px-4.5 py-3">
        <h3 class="text-sm font-medium tracking-tight text-gray-700 dark:text-white">Recent deliveries</h3>
      </header>
      <div class="rounded-xl bg-white text-sm shadow-ui-md ring ring-gray-200 dark:bg-gray-850 dark:ring-gray-700/80">
        <p v-if="!deliveries.length" class="px-4.5 py-4 text-gray-500">
          Nothing sent yet. Send a test to check the URL.
        </p>
        <ul v-else class="divide-y divide-gray-200 dark:divide-gray-700">
          <li v-for="delivery in deliveries" :key="delivery.id">
            <button
              type="button"
              class="flex w-full items-center gap-3 px-4.5 py-3 text-start hover:bg-gray-50 dark:hover:bg-gray-800"
              :aria-expanded="expanded === delivery.id"
              @click="expanded = expanded === delivery.id ? null : delivery.id"
            >
              <StatusCell :value="delivery.status" />
              <code class="text-xs">{{ delivery.event }}</code>
              <span class="flex-1 truncate text-gray-600 dark:text-gray-400">
                {{ delivery.response_status ? `HTTP ${delivery.response_status}` : (delivery.error ?? '') }}
              </span>
              <span class="shrink-0 text-xs text-gray-500">{{ date(delivery.created_at) }}</span>
            </button>
            <div
              v-if="expanded === delivery.id"
              class="space-y-3 border-t border-gray-100 px-4.5 py-3 dark:border-gray-800"
            >
              <p class="text-xs text-gray-600 dark:text-gray-400">
                {{ delivery.attempts }} {{ delivery.attempts === 1 ? 'attempt' : 'attempts' }}
                <template v-if="delivery.duration_ms !== null"> · {{ delivery.duration_ms }} ms</template>
                <template v-if="delivery.next_attempt_at"> · next try {{ date(delivery.next_attempt_at) }}</template>
                <template v-if="delivery.error"> · {{ delivery.error }}</template>
              </p>
              <div v-if="delivery.request_body">
                <p class="mb-1 text-xs font-medium">Request</p>
                <pre tabindex="0" class="max-h-60 overflow-auto rounded-lg bg-gray-50 p-3 text-xs dark:bg-gray-900">{{
                  delivery.request_body
                }}</pre>
              </div>
              <div v-if="delivery.response_body">
                <p class="mb-1 text-xs font-medium">Response</p>
                <pre tabindex="0" class="max-h-60 overflow-auto rounded-lg bg-gray-50 p-3 text-xs dark:bg-gray-900">{{
                  delivery.response_body
                }}</pre>
              </div>
              <Button
                v-if="delivery.event !== 'webhook.test'"
                size="sm"
                variant="outline"
                @click="post(`deliveries/${delivery.id}/resend`)"
                >Resend</Button
              >
            </div>
          </li>
        </ul>
      </div>
    </section>
  </div>
</template>
