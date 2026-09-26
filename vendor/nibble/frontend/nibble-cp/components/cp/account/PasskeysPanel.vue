<script setup lang="ts">
import { router } from '@inertiajs/vue3'
import { ref } from 'vue'
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
import { useConfirm } from '@/lib/confirm'
import { ConfirmationLapsed, registerPasskey, supported } from '@/lib/passkeys'

type Passkey = { id: number; name: string; created_at: string; last_used_at: string | null }

defineProps<{ passkeys: Passkey[] }>()
const open = defineModel<boolean>('open', { default: false })

const confirm = useConfirm()
const adding = ref(false)
const name = ref('')
const busy = ref(false)
const error = ref<string | null>(null)

const date = (value: string) => new Date(value).toLocaleDateString(undefined, { dateStyle: 'medium' })

async function add() {
  busy.value = true
  error.value = null
  try {
    await registerPasskey(name.value.trim() || 'Passkey')
    adding.value = false
    name.value = ''
    router.reload()
  } catch (problem) {
    if (problem instanceof ConfirmationLapsed) return router.reload()
    error.value = problem instanceof Error ? problem.message : 'That passkey was refused.'
  } finally {
    busy.value = false
  }
}

async function remove(passkey: Passkey) {
  const ok = await confirm({
    title: `Remove ${passkey.name}?`,
    description: 'That device can no longer sign you in.',
    confirmText: 'Remove',
    dangerous: true,
  })
  if (ok) router.delete(`/cp/account/passkeys/${passkey.id}`, { preserveScroll: true })
}

async function rename(passkey: Passkey) {
  const next = window.prompt('Name this passkey', passkey.name)
  if (next && next !== passkey.name)
    router.patch(`/cp/account/passkeys/${passkey.id}`, { name: next }, { preserveScroll: true })
}
</script>

<template>
  <Dialog v-model:open="open">
    <DialogContent class="sm:max-w-lg">
      <DialogHeader>
        <DialogTitle>Passkeys</DialogTitle>
        <DialogDescription>
          Sign in with your device's fingerprint, face or screen lock instead of a password.
        </DialogDescription>
      </DialogHeader>
      <ul v-if="passkeys.length" class="divide-y divide-gray-200 dark:divide-gray-700">
        <li v-for="passkey in passkeys" :key="passkey.id" class="flex items-center justify-between gap-3 py-3">
          <div class="min-w-0">
            <p class="truncate text-sm font-medium">{{ passkey.name }}</p>
            <p class="text-xs text-muted-foreground">
              Added {{ date(passkey.created_at) }} ·
              {{ passkey.last_used_at ? `last used ${date(passkey.last_used_at)}` : 'never used' }}
            </p>
          </div>
          <div class="flex gap-2">
            <Button type="button" variant="outline" size="sm" @click="rename(passkey)">Rename</Button>
            <Button type="button" variant="outline" size="sm" @click="remove(passkey)">Remove</Button>
          </div>
        </li>
      </ul>
      <p v-else class="text-sm text-muted-foreground">No passkeys yet.</p>
      <DialogFooter show-close-button>
        <Button v-if="supported()" type="button" @click="adding = true">Add passkey</Button>
        <p v-else class="text-sm text-muted-foreground">This browser doesn't support passkeys.</p>
      </DialogFooter>
    </DialogContent>
  </Dialog>

  <Dialog v-model:open="adding">
    <DialogContent>
      <DialogHeader>
        <DialogTitle>Add a passkey</DialogTitle>
        <DialogDescription>
          Name it so you know which device it is, then follow your browser's prompt.
        </DialogDescription>
      </DialogHeader>
      <form id="passkey-form" class="space-y-1.5" @submit.prevent="add">
        <Label for="passkey-name">Name</Label>
        <Input id="passkey-name" v-model="name" placeholder="Work laptop" />
        <p v-if="error" class="text-sm text-destructive">{{ error }}</p>
      </form>
      <DialogFooter show-close-button>
        <Button type="submit" form="passkey-form" :disabled="busy">Continue</Button>
      </DialogFooter>
    </DialogContent>
  </Dialog>
</template>
