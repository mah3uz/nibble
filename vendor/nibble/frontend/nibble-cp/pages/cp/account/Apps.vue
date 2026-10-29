<script setup lang="ts">
import { Link, router, useForm } from '@inertiajs/vue3'
import { computed, ref, watch } from 'vue'
import AccessChooser, { type Area, type Preset } from '@/components/cp/agents/AccessChooser.vue'
import ConnectionSettings, { type Connection } from '@/components/cp/agents/ConnectionSettings.vue'
import { PRESET_LABELS } from '@/components/cp/agents/connection'
import CpPanel from '@/components/cp/page/CpPanel.vue'
import DataTablePanel from '@/components/cp/page/DataTablePanel.vue'
import PageHeader from '@/components/cp/page/PageHeader.vue'
import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import { Checkbox } from '@/components/ui/checkbox'
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from '@/components/ui/dialog'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select'
import PasswordInput from '@/components/cp/PasswordInput.vue'
import { useBreadcrumbs } from '@/lib/breadcrumbs'
import { useConfirm } from '@/lib/confirm'
import { elevate } from '@/lib/elevation'

type App = Connection & { host: string | null; verified: boolean; created_at: string }

type PendingApproval = {
  id: string
  app: string
  operation: string | null
  title: string | null
  upload: string | null
  created_at: string
}

const props = defineProps<{
  approvals: PendingApproval[]
  enabled: boolean
  site_approvals: 'choose' | 'always'
  can_connect: boolean
  elevated: boolean
  apps: App[]
  presets: Preset[]
  areas: Area[]
  endpoints: { mcp: string; api: string }
  issued: { name: string; token: string } | null
}>()

const confirm = useConfirm()
const creating = ref(false)
const showIssued = ref(!!props.issued)
const password = ref('')
const passwordError = ref<string | null>(null)

watch(
  () => props.issued,
  (issued) => (showIssued.value = !!issued),
)
watch(showIssued, (open) => {
  if (!open && props.issued) router.replaceProp('issued', null)
})

const form = useForm({ name: '', preset: 'read', expires_in: '30', areas: {} as Record<string, string[]> })
const date = (value: string) => new Date(value).toLocaleDateString(undefined, { dateStyle: 'medium' })
const copy = (text: string) => navigator.clipboard.writeText(text)

const editing = ref<App | null>(null)
const settingsOpen = ref(false)
function edit(app: App) {
  editing.value = app
  settingsOpen.value = true
}

const selected = ref<string[]>([])
const deciding = ref<'approve' | 'deny' | null>(null)
const decidingOpen = computed({ get: () => !!deciding.value, set: (open) => !open && (deciding.value = null) })
const batchPassword = ref('')
const batchError = ref<string | null>(null)
const batchProcessing = ref(false)
const noPreview = ref(new Set<string>())
const allSelected = computed(() => props.approvals.length > 0 && selected.value.length === props.approvals.length)

watch(
  () => props.approvals,
  (approvals) => (selected.value = selected.value.filter((id) => approvals.some((approval) => approval.id === id))),
)

function toggleAll(on: boolean) {
  selected.value = on ? props.approvals.map((approval) => approval.id) : []
}

function toggle(id: string, on: boolean) {
  selected.value = on ? [...selected.value, id] : selected.value.filter((item) => item !== id)
}

function askBatch(decision: 'approve' | 'deny') {
  batchPassword.value = ''
  batchError.value = null
  deciding.value = decision
}

async function decideBatch() {
  if (!deciding.value) return
  batchProcessing.value = true
  if (!props.elevated) {
    batchError.value = await elevate(batchPassword.value)
    if (batchError.value) return (batchProcessing.value = false)
  }
  router.post(
    '/cp/approvals/batch',
    { ids: selected.value, decision: deciding.value },
    {
      preserveScroll: true,
      onSuccess: () => {
        deciding.value = null
        selected.value = []
      },
      onFinish: () => (batchProcessing.value = false),
    },
  )
}

async function create() {
  if (!props.elevated) {
    passwordError.value = await elevate(password.value)
    if (passwordError.value) return
  }
  form.post('/cp/account/apps', {
    onSuccess: () => {
      creating.value = false
      form.reset()
      password.value = ''
    },
  })
}

async function disconnect(app: App) {
  const ok = await confirm({
    title: `Disconnect ${app.name}?`,
    description: 'It stops working at once. You can connect it again later.',
    confirmText: 'Disconnect',
    dangerous: true,
  })
  if (ok) router.delete(`/cp/account/apps/${app.id}`, { preserveScroll: true })
}

useBreadcrumbs([{ label: 'Connected apps' }])
</script>

<template>
  <div class="mx-auto max-w-5xl">
    <PageHeader title="Connected apps">
      <template v-if="enabled && can_connect" #actions>
        <Button variant="outline" @click="creating = true">Create token for a script</Button>
      </template>
    </PageHeader>

    <CpPanel v-if="!enabled">
      <p class="rounded-xl bg-white p-5 text-sm shadow-ui-sm dark:bg-gray-900">
        Connecting apps is turned off on this site. An administrator can turn it on under Agent access.
      </p>
    </CpPanel>
    <CpPanel v-else-if="!can_connect">
      <p class="rounded-xl bg-white p-5 text-sm shadow-ui-sm dark:bg-gray-900">
        Your role can't connect apps. Ask an administrator.
      </p>
    </CpPanel>
    <CpPanel v-else title="Connect an app">
      <div class="space-y-2 rounded-xl bg-white p-5 text-sm shadow-ui-sm dark:bg-gray-900">
        <p>Add this address to Claude, ChatGPT, Codex, Cursor or any app that speaks MCP:</p>
        <div class="flex items-center gap-2">
          <code class="grow rounded-lg bg-gray-100 px-3 py-2 font-mono break-all dark:bg-gray-850">{{
            endpoints.mcp
          }}</code>
          <Button variant="outline" size="sm" @click="copy(endpoints.mcp)">Copy</Button>
        </div>
        <p class="text-gray-600 dark:text-gray-400">
          The app sends you here to sign in and choose what it may do. From a terminal, run
          <code class="font-mono">nibble auth login {{ endpoints.mcp.replace(/\/mcp$/, '') }}</code
          >.
        </p>
      </div>
    </CpPanel>

    <CpPanel v-if="approvals.length" title="Waiting for your approval" flush>
      <div
        class="flex flex-wrap items-center justify-between gap-x-4 gap-y-2 border-b border-gray-100 px-4 py-2.5 dark:border-gray-800"
      >
        <label class="flex items-center gap-3 text-sm text-gray-600 dark:text-gray-400">
          <Checkbox :model-value="allSelected" @update:model-value="(on) => toggleAll(!!on)" />
          {{ selected.length ? `${selected.length} of ${approvals.length} selected` : 'Select all' }}
        </label>
        <div class="flex gap-2">
          <Button variant="outline" size="sm" :disabled="!selected.length" @click="askBatch('deny')"
            >Decline selected</Button
          >
          <Button size="sm" :disabled="!selected.length" @click="askBatch('approve')">Approve selected</Button>
        </div>
      </div>
      <ul class="divide-y divide-gray-100 dark:divide-gray-800" role="list">
        <li
          v-for="approval in approvals"
          :key="approval.id"
          class="flex items-center gap-3 ps-4 text-sm hover:bg-gray-50 dark:hover:bg-gray-800/50"
        >
          <Checkbox
            :model-value="selected.includes(approval.id)"
            :aria-label="`Select ${approval.app}: ${approval.title ?? approval.operation ?? 'change'}`"
            @update:model-value="(on) => toggle(approval.id, !!on)"
          />
          <Link
            :href="`/cp/approvals/${approval.id}`"
            class="flex min-w-0 flex-1 items-center justify-between gap-4 py-3 pe-4"
          >
            <span class="flex min-w-0 items-center gap-3">
              <img
                v-if="approval.upload && !noPreview.has(approval.id)"
                :src="`/cp/uploads/${approval.upload}/preview`"
                alt=""
                class="-my-1 size-8 shrink-0 rounded-md bg-gray-100 object-cover dark:bg-gray-800"
                @error="noPreview.add(approval.id)"
              />
              <span class="min-w-0">
                <span class="font-medium">{{ approval.app }}</span> asks to
                {{ (approval.operation ?? 'make a change').toLowerCase()
                }}<template v-if="approval.title">: {{ approval.title }}</template>
              </span>
            </span>
            <span class="shrink-0 text-gray-500">{{ date(approval.created_at) }}</span>
          </Link>
        </li>
      </ul>
    </CpPanel>

    <DataTablePanel v-if="apps.length">
      <thead>
        <tr>
          <th>App</th>
          <th>Access</th>
          <th>Connected</th>
          <th>Last used</th>
          <th>Ends</th>
          <th class="w-44"></th>
        </tr>
      </thead>
      <tbody>
        <tr v-for="app in apps" :key="app.id">
          <td>
            <span class="font-medium">{{ app.name }}</span>
            <span class="block text-xs text-gray-500">
              {{ app.kind === 'ci' ? 'Token for a script' : (app.host ?? (app.verified ? '' : 'Unverified app')) }}
            </span>
          </td>
          <td>
            <div class="flex flex-wrap gap-1.5">
              <Badge variant="secondary">{{ PRESET_LABELS[app.preset] ?? app.preset }}</Badge>
              <Badge variant="secondary">{{ app.asks_approval ? 'Asks first' : "Doesn't ask" }}</Badge>
            </div>
          </td>
          <td class="text-sm">{{ date(app.created_at) }}</td>
          <td class="text-sm">
            {{ app.last_used_at ? date(app.last_used_at) : 'Never' }}
            <span v-if="app.last_used_ip" class="block text-xs text-gray-500">{{ app.last_used_ip }}</span>
          </td>
          <td class="text-sm">{{ date(app.expires_at) }}</td>
          <td>
            <div class="flex justify-end gap-2">
              <Button variant="outline" size="sm" @click="edit(app)">Settings</Button>
              <Button variant="outline" size="sm" @click="disconnect(app)">Disconnect</Button>
            </div>
          </td>
        </tr>
      </tbody>
    </DataTablePanel>
    <p v-else-if="enabled && can_connect" class="text-sm text-gray-600 dark:text-gray-400">No apps connected yet.</p>

    <ConnectionSettings
      v-model:open="settingsOpen"
      :connection="editing"
      url="/cp/account/apps"
      :site-approvals="site_approvals"
      :elevated="elevated"
    />

    <Dialog v-model:open="decidingOpen">
      <DialogContent class="sm:max-w-md">
        <DialogHeader>
          <DialogTitle>
            {{ deciding === 'approve' ? 'Approve' : 'Decline' }} {{ selected.length }}
            {{ selected.length === 1 ? 'request' : 'requests' }}?
          </DialogTitle>
          <DialogDescription>
            <template v-if="deciding === 'approve'">
              Each change is checked again and made at once. One that can't be made is left as it is, with the reason.
            </template>
            <template v-else>None of these changes will be made.</template>
          </DialogDescription>
        </DialogHeader>
        <form v-if="!elevated" id="approvals-batch-form" class="space-y-1.5" @submit.prevent="decideBatch">
          <Label for="approvals-batch-password">Confirm your password</Label>
          <PasswordInput
            id="approvals-batch-password"
            v-model="batchPassword"
            autocomplete="current-password"
            required
          />
          <p v-if="batchError" class="text-sm text-destructive">{{ batchError }}</p>
        </form>
        <DialogFooter show-close-button>
          <Button
            :type="elevated ? 'button' : 'submit'"
            :form="elevated ? undefined : 'approvals-batch-form'"
            :disabled="batchProcessing"
            @click="elevated && decideBatch()"
            >{{ deciding === 'approve' ? 'Approve' : 'Decline' }}</Button
          >
        </DialogFooter>
      </DialogContent>
    </Dialog>

    <Dialog v-model:open="creating">
      <DialogContent>
        <DialogHeader>
          <DialogTitle>Create token for a script</DialogTitle>
          <DialogDescription>
            For CI and scripts that can't sign in with a browser. It acts as you and is shown once.
          </DialogDescription>
        </DialogHeader>
        <form id="app-token-form" class="space-y-4" @submit.prevent="create">
          <div class="space-y-1.5">
            <Label for="app-token-name">Name</Label>
            <Input id="app-token-name" v-model="form.name" placeholder="Nightly import" required />
          </div>
          <AccessChooser
            v-model:preset="form.preset"
            v-model:selection="form.areas"
            :presets="presets"
            :areas="areas"
          />
          <div class="space-y-1.5">
            <Label for="app-token-expiry">Expires</Label>
            <Select v-model="form.expires_in">
              <SelectTrigger id="app-token-expiry" class="w-full"><SelectValue /></SelectTrigger>
              <SelectContent>
                <SelectItem value="7">In 7 days</SelectItem>
                <SelectItem value="30">In 30 days</SelectItem>
                <SelectItem value="90">In 90 days</SelectItem>
              </SelectContent>
            </Select>
          </div>
          <div v-if="!elevated" class="space-y-1.5">
            <Label for="app-token-password">Confirm your password</Label>
            <PasswordInput id="app-token-password" v-model="password" autocomplete="current-password" required />
            <p v-if="passwordError" class="text-sm text-destructive">{{ passwordError }}</p>
          </div>
          <p v-if="form.errors.preset" class="text-sm text-destructive">{{ form.errors.preset }}</p>
        </form>
        <DialogFooter show-close-button>
          <Button type="submit" form="app-token-form" :disabled="form.processing">Create</Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>

    <Dialog v-model:open="showIssued">
      <DialogContent @pointer-down-outside.prevent @interact-outside.prevent @escape-key-down.prevent>
        <DialogHeader>
          <DialogTitle>{{ issued?.name }}</DialogTitle>
          <DialogDescription>
            Copy it now and store it as a secret. It isn't kept anywhere you can read it again.
          </DialogDescription>
        </DialogHeader>
        <code class="block rounded-lg bg-gray-100 px-3 py-2 font-mono text-sm break-all dark:bg-gray-900">
          {{ issued?.token }}
        </code>
        <DialogFooter show-close-button>
          <Button variant="outline" @click="copy(issued?.token ?? '')">Copy</Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  </div>
</template>
