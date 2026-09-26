<script setup lang="ts">
import { router } from '@inertiajs/vue3'
import { BellRing, Eye, EyeOff, RotateCcw } from '@lucide/vue'
import { computed, onBeforeUnmount, onMounted, ref } from 'vue'
import { toast } from 'vue-sonner'
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
import { useCp } from '@/lib/cp'
import { active, confirmCode, expiry, extend, signIn, start, warning, watchExpiry } from '@/lib/session-expiry'

const cp = useCp()
const password = ref('')
const code = ref('')
const visible = ref(false)
const error = ref<string | null>(null)
const busy = ref(false)

start(cp.value.session.lifetime, cp.value.session.remaining)

const showWarning = computed(() => warning() && !expiry.dismissedWarning)
const showSignIn = computed(() => (expiry.signedOut || expiry.twoFactor) && !expiry.dismissedSignIn)
const banner = computed(() => {
  if ((expiry.signedOut || expiry.twoFactor) && expiry.dismissedSignIn)
    return {
      text: "You've been signed out. Click here to sign in again.",
      resume: () => (expiry.dismissedSignIn = false),
    }
  if (warning() && expiry.dismissedWarning)
    return {
      text: 'Your session is about to expire. Click here to extend it.',
      resume: () => (expiry.dismissedWarning = false),
    }
  return null
})

let stop: () => void = () => {}
let stopVisits: () => void = () => {}
onMounted(() => {
  stop = watchExpiry()
  stopVisits = router.on('success', active)
})
onBeforeUnmount(() => {
  stop()
  stopVisits()
})

async function run(step: () => Promise<string | null>) {
  busy.value = true
  error.value = await step()
  busy.value = false
  if (error.value || expiry.twoFactor) return
  password.value = code.value = ''
  toast.success('Signed in')
}

const submitPassword = () => run(() => signIn(cp.value.user?.email_address ?? '', password.value))
const submitCode = () => run(() => confirmCode(code.value))
</script>

<template>
  <button
    v-if="banner"
    type="button"
    class="fixed inset-x-0 top-0 z-50 flex cursor-pointer items-center justify-center gap-2 bg-red-600 px-4 py-2 text-sm font-medium text-white shadow-md hover:bg-red-700"
    @click="banner.resume"
  >
    <BellRing class="size-4" />
    <span>{{ banner.text }}</span>
  </button>

  <Dialog :open="showWarning">
    <DialogContent
      class="sm:max-w-[500px]"
      :show-close-button="false"
      @escape-key-down.prevent
      @pointer-down-outside.prevent
      @interact-outside.prevent
    >
      <DialogHeader>
        <DialogTitle>Your Session is Expiring</DialogTitle>
        <DialogDescription aria-live="polite">
          You have been inactive for a while and will be signed out in
          <span class="font-medium text-gray-900 tabular-nums dark:text-white">{{ expiry.count }}</span>
          {{ expiry.count === 1 ? 'second' : 'seconds' }}.
        </DialogDescription>
      </DialogHeader>
      <DialogFooter>
        <Button type="button" variant="ghost" @click="expiry.dismissedWarning = true">Cancel</Button>
        <Button type="button" @click="extend"><RotateCcw /> Extend Session</Button>
      </DialogFooter>
    </DialogContent>
  </Dialog>

  <Dialog :open="showSignIn">
    <DialogContent
      class="sm:max-w-[500px]"
      :show-close-button="false"
      @escape-key-down.prevent
      @pointer-down-outside.prevent
      @interact-outside.prevent
    >
      <DialogHeader>
        <DialogTitle>Resume Your Session</DialogTitle>
        <DialogDescription v-if="!expiry.twoFactor">
          You were signed out after a while without activity. Enter the password for
          <span class="font-medium text-gray-900 dark:text-white">{{ cp.user?.email_address }}</span> to carry on where
          you left off.
        </DialogDescription>
        <DialogDescription v-else>Enter the code from your authenticator app, or a recovery code.</DialogDescription>
      </DialogHeader>

      <form v-if="!expiry.twoFactor" class="space-y-1.5" @submit.prevent="submitPassword">
        <div class="flex items-center gap-2 sm:gap-3">
          <div class="relative flex-1">
            <Input
              id="session-password"
              v-model="password"
              :type="visible ? 'text' : 'password'"
              autocomplete="current-password"
              aria-label="Password"
              class="pe-10"
              required
              autofocus
            />
            <button
              type="button"
              class="absolute inset-y-0 end-0 flex w-10 cursor-pointer items-center justify-center text-gray-500 hover:text-gray-800 dark:hover:text-gray-200"
              :aria-label="visible ? 'Hide password' : 'Show password'"
              @click="visible = !visible"
            >
              <component :is="visible ? EyeOff : Eye" class="size-4" />
            </button>
          </div>
          <Button type="submit" :disabled="busy">Sign in</Button>
        </div>
        <p v-if="error" class="text-sm text-destructive">{{ error }}</p>
      </form>

      <form v-else class="space-y-1.5" @submit.prevent="submitCode">
        <div class="flex items-center gap-2 sm:gap-3">
          <Input
            id="session-code"
            v-model="code"
            autocomplete="one-time-code"
            inputmode="numeric"
            aria-label="Code"
            class="flex-1"
            required
            autofocus
          />
          <Button type="submit" :disabled="busy">Verify</Button>
        </div>
        <p v-if="error" class="text-sm text-destructive">{{ error }}</p>
      </form>

      <DialogFooter>
        <Button type="button" variant="ghost" @click="expiry.dismissedSignIn = true">Not now</Button>
      </DialogFooter>
    </DialogContent>
  </Dialog>
</template>
