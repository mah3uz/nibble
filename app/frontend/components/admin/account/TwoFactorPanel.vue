<script setup lang="ts">
import { router, useForm, usePage } from '@inertiajs/vue3'
import { computed, ref, watch } from 'vue'
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
import { Popover, PopoverContent, PopoverTrigger } from '@/components/ui/popover'

const props = defineProps<{
  hasPasskeys: boolean
  twoFactor: {
    enabled: boolean
    required: boolean
    pending: { secret: string; uri: string; qr: string } | null
    recovery_codes_left: number
    recovery_codes: string[] | null
  }
}>()

const errors = computed(() => usePage().props.errors as unknown as Record<string, string>)

const setup = ref(!!props.twoFactor.pending)
const codes = ref(!!props.twoFactor.recovery_codes?.length)
const asking = ref<'disable' | 'recovery_codes' | null>(null)

watch(
  () => props.twoFactor.pending,
  (pending) => (setup.value = !!pending),
)
watch(
  () => props.twoFactor.recovery_codes,
  (list) => (codes.value = !!list?.length),
)

const open = ref(false)
function begin(action: () => void) {
  open.value = false
  action()
}

const confirmForm = useForm({ code: '' })
const passwordForm = useForm({ current_password: '' })

async function start() {
  router.post('/admin/account/two_factor', {}, { preserveScroll: true })
}

async function confirm() {
  confirmForm.post('/admin/account/two_factor/confirm', {
    preserveScroll: true,
    onSuccess: () => confirmForm.reset(),
  })
}

async function submitPassword() {
  const url = asking.value === 'disable' ? '/admin/account/two_factor' : '/admin/account/two_factor/recovery_codes'
  const options = {
    preserveScroll: true,
    onSuccess: () => {
      asking.value = null
      passwordForm.reset()
    },
  }
  if (asking.value === 'disable') passwordForm.delete(url, options)
  else passwordForm.post(url, options)
}

const copyCodes = () => navigator.clipboard.writeText((props.twoFactor.recovery_codes ?? []).join('\n'))

// They stay on screen until they say they have them: a reload shouldn't cost someone their way back in.
async function keptCodes() {
  const csrf = document.querySelector<HTMLMetaElement>('meta[name=csrf-token]')?.content ?? ''
  void fetch('/admin/account/two_factor/recovery_codes/ack', {
    method: 'POST',
    headers: { Accept: 'application/json', 'X-CSRF-Token': csrf },
  })
  codes.value = false
}
</script>

<template>
  <Popover v-model:open="open">
    <PopoverTrigger as-child>
      <Button type="button" variant="outline">Two-Factor Authentication</Button>
    </PopoverTrigger>
    <PopoverContent align="end" class="w-96 space-y-3 p-4">
      <p class="text-sm text-gray-600 dark:text-gray-400">
        When turned on, you're asked for a code from your authenticator app every time you sign in.
      </p>
      <p v-if="twoFactor.enabled" class="text-sm text-gray-900 dark:text-white">
        Authenticator app on. {{ twoFactor.recovery_codes_left }} recovery
        {{ twoFactor.recovery_codes_left === 1 ? 'code' : 'codes' }} left.
      </p>
      <p v-else-if="twoFactor.required" class="text-sm text-destructive">
        Your role requires two-factor authentication. Set it up to carry on working.
      </p>
      <div class="flex flex-wrap gap-2">
        <Button v-if="!twoFactor.enabled" type="button" variant="outline" @click="begin(start)"
          >Enable two-factor authentication</Button
        >
        <template v-else>
          <Button type="button" variant="outline" @click="begin(() => (asking = 'recovery_codes'))"
            >New recovery codes</Button
          >
          <Button
            v-if="!twoFactor.required || hasPasskeys"
            type="button"
            variant="outline"
            @click="begin(() => (asking = 'disable'))"
          >
            Turn off
          </Button>
        </template>
      </div>
    </PopoverContent>
  </Popover>

  <Dialog v-model:open="setup">
    <DialogContent>
      <DialogHeader>
        <DialogTitle>Set up two-factor authentication</DialogTitle>
        <DialogDescription>
          Scan the QR code with your authenticator app, or type the setup key. Then enter the six-digit code it shows.
        </DialogDescription>
      </DialogHeader>
      <div v-if="twoFactor.pending" class="flex flex-col gap-4 sm:flex-row">
        <!-- eslint-disable-next-line vue/no-v-html -->
        <div class="size-40 shrink-0 rounded-lg bg-white p-2 ring ring-gray-200" v-html="twoFactor.pending.qr" />
        <form id="totp-form" class="flex-1 space-y-4" @submit.prevent="confirm">
          <div class="space-y-1.5">
            <Label for="totp-secret">Setup key</Label>
            <Input id="totp-secret" :model-value="twoFactor.pending.secret" readonly class="font-mono" />
          </div>
          <div class="space-y-1.5">
            <Label for="totp-code">Verification code</Label>
            <Input
              id="totp-code"
              v-model="confirmForm.code"
              inputmode="numeric"
              autocomplete="one-time-code"
              required
              autofocus
            />
            <p v-if="errors.code" class="text-sm text-destructive">{{ errors.code }}</p>
          </div>
        </form>
      </div>
      <DialogFooter show-close-button>
        <Button type="submit" form="totp-form" :disabled="confirmForm.processing">Confirm</Button>
      </DialogFooter>
    </DialogContent>
  </Dialog>

  <Dialog :open="codes" @update:open="(open) => !open && keptCodes()">
    <DialogContent>
      <DialogHeader>
        <DialogTitle>Recovery codes</DialogTitle>
        <DialogDescription>
          Keep these somewhere safe. Each one signs you in once if you lose your authenticator app, and they're shown
          only now.
        </DialogDescription>
      </DialogHeader>
      <ul class="grid grid-cols-2 gap-2 font-mono text-sm">
        <li v-for="code in twoFactor.recovery_codes ?? []" :key="code">{{ code }}</li>
      </ul>
      <DialogFooter>
        <Button type="button" variant="outline" @click="copyCodes">Copy</Button>
        <Button type="button" @click="keptCodes">I've saved them</Button>
      </DialogFooter>
    </DialogContent>
  </Dialog>

  <Dialog :open="!!asking" @update:open="(open) => !open && (asking = null)">
    <DialogContent>
      <DialogHeader>
        <DialogTitle>{{ asking === 'disable' ? 'Turn off the authenticator app' : 'New recovery codes' }}</DialogTitle>
        <DialogDescription>
          {{
            asking !== 'disable'
              ? 'The codes you have now stop working.'
              : hasPasskeys
                ? 'Your passkeys still sign you in, so you will still be asked for one.'
                : 'Your account goes back to password only.'
          }}
        </DialogDescription>
      </DialogHeader>
      <form id="password-form" class="space-y-1.5" @submit.prevent="submitPassword">
        <Label for="twofactor-password">Current password</Label>
        <Input
          id="twofactor-password"
          v-model="passwordForm.current_password"
          type="password"
          autocomplete="current-password"
          required
        />
        <p v-if="errors.current_password" class="text-sm text-destructive">{{ errors.current_password }}</p>
      </form>
      <DialogFooter show-close-button>
        <Button type="submit" form="password-form" :disabled="passwordForm.processing">Continue</Button>
      </DialogFooter>
    </DialogContent>
  </Dialog>
</template>
