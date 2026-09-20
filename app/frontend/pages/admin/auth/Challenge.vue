<script setup lang="ts">
import { useForm } from '@inertiajs/vue3'
import { ref } from 'vue'
import { Button } from '@/components/ui/button'
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { useFlashToasts } from '@/lib/admin'
import { signInWithPasskey, supported } from '@/lib/passkeys'

const props = defineProps<{ flash: { notice?: string; alert?: string } }>()
useFlashToasts(() => props.flash)
const passkeyError = ref<string | null>(null)

async function usePasskey() {
  passkeyError.value = null
  try {
    await signInWithPasskey()
  } catch (problem) {
    passkeyError.value = problem instanceof Error ? problem.message : 'That passkey was refused.'
  }
}

const form = useForm({ code: '' })
</script>

<template>
  <Card>
    <CardHeader>
      <CardTitle>Two-factor authentication</CardTitle>
      <CardDescription>
        Use your passkey, or enter the code from your authenticator app or one of your recovery codes.
      </CardDescription>
    </CardHeader>
    <CardContent>
      <form class="space-y-4" @submit.prevent="form.post('/admin/session/challenge')">
        <div class="space-y-2">
          <Label for="code">Code</Label>
          <Input
            id="code"
            v-model="form.code"
            inputmode="text"
            autocomplete="one-time-code"
            spellcheck="false"
            required
            autofocus
          />
        </div>
        <Button type="submit" class="w-full" :disabled="form.processing">Continue</Button>
        <template v-if="supported()">
          <p class="text-center text-xs text-muted-foreground">Or sign in with</p>
          <Button type="button" variant="outline" class="w-full" @click="usePasskey">Passkey</Button>
          <p v-if="passkeyError" class="text-center text-sm text-destructive">{{ passkeyError }}</p>
        </template>
      </form>
    </CardContent>
  </Card>
</template>
