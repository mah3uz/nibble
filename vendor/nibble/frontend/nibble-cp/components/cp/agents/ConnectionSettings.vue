<script setup lang="ts">
import { useForm } from '@inertiajs/vue3'
import { computed, ref, watch } from 'vue'
import AccessChooser, { type Area, type Preset } from '@/components/cp/agents/AccessChooser.vue'
import ApprovalsChooser from '@/components/cp/agents/ApprovalsChooser.vue'
import PasswordInput from '@/components/cp/PasswordInput.vue'
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
import { elevate } from '@/lib/elevation'
import { connectionEnds, connectionVia, lastUsed } from './connection'

export type Connection = {
  id: number
  kind: string
  name: string
  preset: string
  areas: Record<string, string[]>
  approval_mode: string
  asks_approval: boolean
  via: string | null
  last_used_at: string | null
  last_used_ip: string | null
  expires_at: string
  owner?: { id: number; name: string; email: string }
  options: { presets: Preset[]; areas: Area[]; approvals_choosable: boolean }
}

const props = defineProps<{
  connection: Connection | null
  url: string
  siteApprovals: string
  elevated: boolean
}>()
const open = defineModel<boolean>('open', { required: true })

const form = useForm({ name: '', preset: '', areas: {} as Record<string, string[]>, approval_mode: 'ask' })
const password = ref('')
const passwordError = ref<string | null>(null)

watch(
  () => [open.value, props.connection] as const,
  ([isOpen, connection]) => {
    if (!isOpen || !connection) return
    form.defaults({
      name: connection.name,
      preset: connection.preset,
      areas: Object.fromEntries(Object.entries(connection.areas).map(([area, columns]) => [area, [...columns]])),
      approval_mode: connection.approval_mode,
    })
    form.reset()
    form.clearErrors()
    password.value = ''
    passwordError.value = null
  },
  { immediate: true },
)

const sameAreas = (a: Record<string, string[]>, b: Record<string, string[]>) => {
  const normal = (value: Record<string, string[]>) =>
    JSON.stringify(
      Object.keys(value)
        .filter((key) => value[key].length)
        .sort()
        .map((key) => [key, [...value[key]].sort()]),
    )
  return normal(a) === normal(b)
}

const choosable = computed(() => !!props.connection?.options.approvals_choosable && props.siteApprovals !== 'always')
const changes = computed(() => {
  const connection = props.connection
  if (!connection) return {}
  const changed: Record<string, unknown> = {}
  const name = form.name.trim()
  if (name !== connection.name) changed.name = name
  if (form.preset !== connection.preset || (form.preset === 'custom' && !sameAreas(form.areas, connection.areas))) {
    changed.preset = form.preset
    if (form.preset === 'custom') changed.areas = form.areas
  }
  if (choosable.value && form.approval_mode !== connection.approval_mode) changed.approval_mode = form.approval_mode
  return changed
})
const changesAccess = computed(() => Object.keys(changes.value).some((key) => key !== 'name'))
const needsPassword = computed(() => changesAccess.value && !props.elevated)

async function save() {
  if (!props.connection || !Object.keys(changes.value).length) return
  if (needsPassword.value) {
    passwordError.value = await elevate(password.value)
    if (passwordError.value) return
  }
  const changed = changes.value
  form
    .transform(() => changed)
    .patch(`${props.url}/${props.connection.id}`, {
      preserveScroll: true,
      onSuccess: () => (open.value = false),
    })
}
</script>

<template>
  <Dialog v-model:open="open">
    <DialogContent class="sm:max-w-xl">
      <DialogHeader>
        <DialogTitle>{{ connection?.name }}</DialogTitle>
        <DialogDescription
          >Changes apply from the app's next request. It doesn't need to sign in again.</DialogDescription
        >
      </DialogHeader>
      <form v-if="connection" id="connection-settings-form" class="space-y-5" @submit.prevent="save">
        <div class="space-y-1.5">
          <Label for="connection-name">Name</Label>
          <Input id="connection-name" v-model="form.name" maxlength="100" required />
          <p v-if="form.errors.name" class="text-sm text-destructive">{{ form.errors.name }}</p>
        </div>

        <div class="space-y-1.5">
          <p class="text-sm font-medium">What it may do</p>
          <AccessChooser
            v-model:preset="form.preset"
            v-model:selection="form.areas"
            :presets="connection.options.presets"
            :areas="connection.options.areas"
          />
          <p v-if="form.errors.preset" class="text-sm text-destructive">{{ form.errors.preset }}</p>
        </div>

        <div>
          <ApprovalsChooser v-if="choosable" v-model="form.approval_mode" />
          <template v-else>
            <p class="mb-1 text-sm font-medium">Approvals</p>
            <p class="text-sm text-muted-foreground">
              <template v-if="connection.kind === 'ci'">
                A token for a script makes changes without asking: nobody is there to approve them.
              </template>
              <template v-else-if="siteApprovals === 'always'">
                This site always asks before live changes. An administrator can change that under Agent access.
              </template>
              <template v-else>Signed in with a code, so it always asks before live changes.</template>
            </p>
          </template>
          <p v-if="form.errors.approval_mode" class="mt-1.5 text-sm text-destructive">
            {{ form.errors.approval_mode }}
          </p>
        </div>

        <dl class="grid grid-cols-[auto_1fr] gap-x-4 gap-y-1 rounded-lg bg-muted/60 p-3 text-sm">
          <template v-if="connection.owner">
            <dt class="text-muted-foreground">Person</dt>
            <dd class="truncate">
              {{ connection.owner.name }} <span class="text-muted-foreground">{{ connection.owner.email }}</span>
            </dd>
          </template>
          <dt class="text-muted-foreground">Signed in</dt>
          <dd>{{ connectionVia(connection) }}</dd>
          <dt class="text-muted-foreground">Last used</dt>
          <dd>{{ lastUsed(connection) }}</dd>
          <dt class="text-muted-foreground">Ends</dt>
          <dd>{{ connectionEnds(connection) }}</dd>
        </dl>

        <div v-if="needsPassword" class="space-y-1.5">
          <Label for="connection-password">Confirm your password</Label>
          <PasswordInput id="connection-password" v-model="password" autocomplete="current-password" required />
          <p v-if="passwordError" class="text-sm text-destructive">{{ passwordError }}</p>
        </div>
      </form>
      <DialogFooter show-close-button>
        <Button
          type="submit"
          form="connection-settings-form"
          :disabled="form.processing || !Object.keys(changes).length"
          >Save</Button
        >
      </DialogFooter>
    </DialogContent>
  </Dialog>
</template>
