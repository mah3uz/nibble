<script setup lang="ts">
import { useForm } from '@inertiajs/vue3'
import { computed, ref } from 'vue'
import AccessChooser, { type Area, type Preset } from '@/components/cp/agents/AccessChooser.vue'
import { Alert, AlertDescription } from '@/components/ui/alert'
import { Button } from '@/components/ui/button'
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card'
import { Label } from '@/components/ui/label'
import PasswordInput from '@/components/cp/PasswordInput.vue'
import { elevate } from '@/lib/elevation'

const props = defineProps<{
  request_id: string
  site: string
  presets: Preset[]
  areas: Area[]
  elevated: boolean
  client: {
    name: string
    known: string | null
    client_id: string
    id_host: string | null
    redirect_host: string | null
    loopback: boolean
    verified: boolean
  }
  device: { code: string; ip: string | null } | null
}>()

const firstAvailable = props.presets.find((preset) => preset.available && preset.value !== 'everything')
const form = useForm({
  request_id: props.request_id,
  decision: 'approve',
  preset: firstAvailable?.value ?? 'read',
  areas: {} as Record<string, string[]>,
})
const password = ref('')
const passwordError = ref<string | null>(null)
const needsPassword = computed(() => form.preset === 'everything' && !props.elevated)
const title = computed(() => props.client.known ?? props.client.name)

async function submit(decision: 'approve' | 'deny') {
  if (decision === 'approve' && needsPassword.value) {
    passwordError.value = await elevate(password.value)
    if (passwordError.value) return
  }
  form.decision = decision
  form.post('/oauth/authorize')
}
</script>

<template>
  <Card>
    <CardHeader>
      <CardTitle>Connect {{ title }}</CardTitle>
      <CardDescription>It will work on {{ site }} as you, and never do more than you can.</CardDescription>
    </CardHeader>
    <CardContent class="space-y-4">
      <dl class="space-y-1 rounded-lg bg-muted/60 p-3 text-sm">
        <div v-if="client.id_host" class="flex justify-between gap-3">
          <dt class="text-muted-foreground">App</dt>
          <dd class="truncate font-medium">{{ client.id_host }}</dd>
        </div>
        <div v-else-if="!client.verified" class="flex justify-between gap-3">
          <dt class="text-muted-foreground">App</dt>
          <dd class="font-medium">Unverified: it named itself</dd>
        </div>
        <div v-if="client.redirect_host" class="flex justify-between gap-3">
          <dt class="text-muted-foreground">Returns to</dt>
          <dd class="truncate font-medium">{{ client.redirect_host }}</dd>
        </div>
        <div v-if="device" class="flex justify-between gap-3">
          <dt class="text-muted-foreground">Code</dt>
          <dd class="font-mono font-medium">{{ device.code }}</dd>
        </div>
      </dl>

      <Alert v-if="device">
        <AlertDescription>
          You're signing in an app on another device<template v-if="device.ip"> ({{ device.ip }})</template>. Only
          continue if you started this yourself, just now.
        </AlertDescription>
      </Alert>
      <Alert v-else-if="client.loopback && !client.known">
        <AlertDescription>
          This app runs on a computer, not a website. Only continue if you started this from an app you trust.
        </AlertDescription>
      </Alert>

      <AccessChooser v-model:preset="form.preset" v-model:selection="form.areas" :presets="presets" :areas="areas" />

      <div v-if="needsPassword" class="space-y-1.5">
        <Label for="consent-password">Confirm your password</Label>
        <PasswordInput id="consent-password" v-model="password" autocomplete="current-password" />
        <p v-if="passwordError" class="text-sm text-destructive">{{ passwordError }}</p>
      </div>
      <p v-if="form.errors.preset" class="text-sm text-destructive">{{ form.errors.preset }}</p>

      <div class="flex gap-2">
        <Button class="flex-1" :disabled="form.processing" @click="submit('approve')">Connect</Button>
        <Button variant="outline" class="flex-1" :disabled="form.processing" @click="submit('deny')">Cancel</Button>
      </div>
      <p class="text-center text-xs text-muted-foreground">You can disconnect it any time under Connected apps.</p>
    </CardContent>
  </Card>
</template>
