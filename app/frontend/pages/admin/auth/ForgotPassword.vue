<script setup lang="ts">
import { useForm } from '@inertiajs/vue3'
import { Button } from '@/components/ui/button'
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { useFlashToasts } from '@/lib/admin'

const props = defineProps<{ flash: { notice?: string; alert?: string } }>()
useFlashToasts(() => props.flash)
const form = useForm({ email_address: '' })
</script>

<template>
  <Card>
    <CardHeader>
      <CardTitle>Reset your password</CardTitle>
      <CardDescription>We'll email you a reset link.</CardDescription>
    </CardHeader>
    <CardContent>
      <form class="space-y-4" @submit.prevent="form.post('/admin/passwords')">
        <div class="space-y-2">
          <Label for="email">Email</Label>
          <Input id="email" v-model="form.email_address" type="email" required autofocus />
        </div>
        <Button type="submit" class="w-full" :disabled="form.processing">Email reset link</Button>
      </form>
    </CardContent>
  </Card>
</template>
