<script setup lang="ts">
import { useForm } from '@inertiajs/vue3'
import { Button } from '@/components/ui/button'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { useFlashToasts } from '@/lib/cp'

const props = defineProps<{ token: string; flash: { notice?: string; alert?: string } }>()
useFlashToasts(() => props.flash)
const form = useForm({ password: '', password_confirmation: '' })
</script>

<template>
  <Card>
    <CardHeader><CardTitle>Choose a new password</CardTitle></CardHeader>
    <CardContent>
      <form class="space-y-4" @submit.prevent="form.put(`/cp/passwords/${token}`)">
        <div class="space-y-2">
          <Label for="password">New password</Label>
          <Input
            id="password"
            v-model="form.password"
            type="password"
            autocomplete="new-password"
            required
            minlength="12"
          />
        </div>
        <div class="space-y-2">
          <Label for="password_confirmation">Confirm password</Label>
          <Input
            id="password_confirmation"
            v-model="form.password_confirmation"
            type="password"
            autocomplete="new-password"
            required
          />
        </div>
        <Button type="submit" class="w-full" :disabled="form.processing">Save password</Button>
      </form>
    </CardContent>
  </Card>
</template>
