<script setup lang="ts">
import { Link, useForm } from '@inertiajs/vue3'
import { ref } from 'vue'
import { Button } from '@/components/ui/button'
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { useFlashToasts } from '@/lib/cp'
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

const form = useForm({ email_address: '', password: '' })
</script>

<template>
  <Card>
    <CardHeader>
      <CardTitle>Sign in</CardTitle>
      <CardDescription>Use your CMS account.</CardDescription>
    </CardHeader>
    <CardContent>
      <form class="space-y-4" @submit.prevent="form.post('/cp/session')">
        <div class="space-y-2">
          <Label for="email">Email</Label>
          <Input id="email" v-model="form.email_address" type="email" autocomplete="username" required autofocus />
        </div>
        <div class="space-y-2">
          <Label for="password">Password</Label>
          <Input id="password" v-model="form.password" type="password" autocomplete="current-password" required />
        </div>
        <Button type="submit" class="w-full" :disabled="form.processing">Sign in</Button>
        <template v-if="supported()">
          <p class="text-center text-xs text-muted-foreground">Or sign in with</p>
          <Button type="button" variant="outline" class="w-full" @click="usePasskey">Passkey</Button>
          <p v-if="passkeyError" class="text-center text-sm text-destructive">{{ passkeyError }}</p>
        </template>
        <p class="text-center text-sm">
          <Link href="/cp/passwords/new" class="text-muted-foreground hover:underline">Forgot password?</Link>
        </p>
      </form>
    </CardContent>
  </Card>
</template>
