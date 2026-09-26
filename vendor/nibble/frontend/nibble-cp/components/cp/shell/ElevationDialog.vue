<script setup lang="ts">
import { BellRing, Eye, EyeOff, RotateCcw } from '@lucide/vue'
import { onBeforeUnmount, onMounted, ref, watch } from 'vue'
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
import { elevate, elevation, extendSession, watchIdle } from '@/lib/elevation'

const cp = useCp()
const password = ref('')
const visible = ref(false)
const error = ref<string | null>(null)
const busy = ref(false)

watch(
  () => cp.value.elevated_until,
  (until) => (elevation.elevatedUntil = until ? Date.parse(until) : null),
  { immediate: true },
)

let stop: () => void = () => {}
onMounted(() => (stop = watchIdle()))
onBeforeUnmount(() => stop())

async function unlock() {
  busy.value = true
  error.value = await elevate(password.value)
  if (!error.value) password.value = ''
  busy.value = false
}
</script>

<template>
  <button
    v-if="elevation.warning && elevation.dismissed"
    type="button"
    class="fixed inset-x-0 top-0 z-50 flex cursor-pointer items-center justify-center gap-2 bg-red-600 px-4 py-2 text-sm font-medium text-white shadow-md hover:bg-red-700"
    @click="elevation.dismissed = false"
  >
    <BellRing class="size-4" />
    <span>Your session is about to lock. Click here to extend it and stay signed in.</span>
  </button>

  <Dialog :open="elevation.warning && !elevation.dismissed">
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
          You have been inactive for a while and will be locked out in
          <span class="font-medium text-gray-900 tabular-nums dark:text-white">{{ elevation.remaining }}</span>
          {{ elevation.remaining === 1 ? 'second' : 'seconds' }}.
        </DialogDescription>
      </DialogHeader>
      <DialogFooter>
        <Button type="button" variant="ghost" @click="elevation.dismissed = true">Cancel</Button>
        <Button type="button" @click="extendSession"><RotateCcw /> Extend Session</Button>
      </DialogFooter>
    </DialogContent>
  </Dialog>

  <Dialog :open="elevation.locked">
    <DialogContent
      class="sm:max-w-[500px]"
      :show-close-button="false"
      @escape-key-down.prevent
      @pointer-down-outside.prevent
      @interact-outside.prevent
    >
      <DialogHeader>
        <DialogTitle>Resume Your Session</DialogTitle>
        <DialogDescription>Enter your password to continue.</DialogDescription>
      </DialogHeader>
      <form class="space-y-1.5" @submit.prevent="unlock">
        <div class="flex items-center gap-2 sm:gap-3">
          <div class="relative flex-1">
            <Input
              id="elevate-password"
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
          <Button type="submit" :disabled="busy">Continue</Button>
        </div>
        <p v-if="error" class="text-sm text-destructive">{{ error }}</p>
      </form>
    </DialogContent>
  </Dialog>
</template>
