<script setup lang="ts">
import { Link, router, useForm } from '@inertiajs/vue3'
import { ref, watch } from 'vue'
import AccessChooser, { type Area, type Preset } from '@/components/cp/agents/AccessChooser.vue'
import CpPanel from '@/components/cp/page/CpPanel.vue'
import DataTablePanel from '@/components/cp/page/DataTablePanel.vue'
import PageHeader from '@/components/cp/page/PageHeader.vue'
import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
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
import { useBreadcrumbs } from '@/lib/breadcrumbs'
import { useConfirm } from '@/lib/confirm'
import { elevate } from '@/lib/elevation'

type App = {
  id: number
  name: string
  kind: string
  preset: string
  via: string | null
  host: string | null
  verified: boolean
  created_at: string
  last_used_at: string | null
  last_used_ip: string | null
  expires_at: string
}

type PendingApproval = { id: string; app: string; operation: string | null; title: string | null; created_at: string }

const props = defineProps<{
  approvals: PendingApproval[]
  enabled: boolean
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

    <CpPanel v-if="approvals.length" title="Waiting for your approval">
      <ul class="divide-y divide-gray-100 rounded-xl bg-white shadow-ui-sm dark:divide-gray-800 dark:bg-gray-900">
        <li v-for="approval in approvals" :key="approval.id">
          <Link
            :href="`/cp/approvals/${approval.id}`"
            class="flex items-center justify-between gap-4 p-4 text-sm hover:bg-gray-50 dark:hover:bg-gray-850"
          >
            <span>
              <span class="font-medium">{{ approval.app }}</span> asks to
              {{ (approval.operation ?? 'make a change').toLowerCase()
              }}<template v-if="approval.title">: {{ approval.title }}</template>
            </span>
            <span class="text-gray-500">{{ date(approval.created_at) }}</span>
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
          <th>Expires</th>
          <th class="w-28"></th>
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
            <Badge variant="secondary">{{ app.preset }}</Badge>
          </td>
          <td class="text-sm">{{ date(app.created_at) }}</td>
          <td class="text-sm">
            {{ app.last_used_at ? date(app.last_used_at) : 'Never' }}
            <span v-if="app.last_used_ip" class="block text-xs text-gray-500">{{ app.last_used_ip }}</span>
          </td>
          <td class="text-sm">{{ date(app.expires_at) }}</td>
          <td><Button variant="outline" size="sm" @click="disconnect(app)">Disconnect</Button></td>
        </tr>
      </tbody>
    </DataTablePanel>
    <p v-else-if="enabled && can_connect" class="text-sm text-gray-600 dark:text-gray-400">No apps connected yet.</p>

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
            <Input
              id="app-token-password"
              v-model="password"
              type="password"
              autocomplete="current-password"
              required
            />
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
