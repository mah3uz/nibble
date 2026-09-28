<script setup lang="ts">
import { router } from '@inertiajs/vue3'
import { ref } from 'vue'
import CpIcon from '@/components/cp/icons/CpIcon.vue'
import { Button } from '@/components/ui/button'
import { Label } from '@/components/ui/label'
import PasswordInput from '@/components/cp/PasswordInput.vue'
import { elevate } from '@/lib/elevation'

const password = ref('')
const busy = ref(false)
const error = ref<string | null>(null)

async function submit() {
  busy.value = true
  error.value = await elevate(password.value)
  busy.value = false
  if (!error.value) router.reload()
}
</script>

<template>
  <div class="mx-auto max-w-md pt-8">
    <div class="rounded-2xl bg-gray-150 p-1.75 shadow-ui-xl dark:bg-gray-950/35">
      <form
        class="rounded-xl bg-white p-4 shadow-ui-md ring ring-gray-200 dark:bg-gray-850 dark:ring-gray-700/80"
        @submit.prevent="submit"
      >
        <div class="flex flex-col items-center pt-3 pb-6 text-center">
          <span
            class="mb-3 flex size-10 items-center justify-center rounded-lg bg-white shadow-ui-sm ring ring-gray-200 dark:bg-gray-800 dark:ring-gray-700"
            ><CpIcon name="key" class="size-5 text-gray-700 dark:text-gray-300"
          /></span>
          <h1 class="text-lg font-medium text-gray-900 dark:text-white">Confirm Your Identity</h1>
          <p class="mt-1 text-sm text-gray-600 dark:text-gray-400">
            For security, please re-authenticate your account.
          </p>
        </div>
        <div class="space-y-2">
          <Label for="confirm-password">Password</Label>
          <PasswordInput id="confirm-password" v-model="password" autocomplete="current-password" required autofocus />
          <p v-if="error" class="text-sm text-destructive">{{ error }}</p>
        </div>
        <Button type="submit" class="mt-6 w-full" :disabled="busy">Submit</Button>
      </form>
    </div>
  </div>
</template>
