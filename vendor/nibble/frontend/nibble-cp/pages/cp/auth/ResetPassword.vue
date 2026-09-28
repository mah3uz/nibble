<script setup lang="ts">
import { useForm } from '@inertiajs/vue3'
import { CircleAlert } from '@lucide/vue'
import { Alert, AlertDescription } from '@/components/ui/alert'
import { Button } from '@/components/ui/button'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { Label } from '@/components/ui/label'
import PasswordInput from '@/components/cp/PasswordInput.vue'
import { useFlashToasts } from '@/lib/cp'

const props = defineProps<{ token: string; flash: { notice?: string; alert?: string } }>()
useFlashToasts(() => ({ notice: props.flash.notice }))
const form = useForm({ password: '', password_confirmation: '' })
</script>

<template>
  <Card>
    <CardHeader><CardTitle>Choose a new password</CardTitle></CardHeader>
    <CardContent>
      <form class="space-y-4" @submit.prevent="form.put(`/cp/passwords/${token}`)">
        <Alert v-if="flash.alert && !form.processing" variant="destructive">
          <CircleAlert />
          <AlertDescription>{{ flash.alert }}</AlertDescription>
        </Alert>
        <div class="space-y-2">
          <Label for="password">New password</Label>
          <PasswordInput id="password" v-model="form.password" autocomplete="new-password" required minlength="12" />
        </div>
        <div class="space-y-2">
          <Label for="password_confirmation">Confirm password</Label>
          <PasswordInput
            id="password_confirmation"
            v-model="form.password_confirmation"
            autocomplete="new-password"
            required
          />
        </div>
        <Button type="submit" class="w-full" :disabled="form.processing">Save password</Button>
      </form>
    </CardContent>
  </Card>
</template>
