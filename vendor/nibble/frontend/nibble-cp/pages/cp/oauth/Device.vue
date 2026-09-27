<script setup lang="ts">
import { useForm } from '@inertiajs/vue3'
import { Button } from '@/components/ui/button'
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'

const props = defineProps<{ code: string }>()
const form = useForm({ code: props.code })
</script>

<template>
  <Card>
    <CardHeader>
      <CardTitle>Connect a device</CardTitle>
      <CardDescription>Type the code the app is showing you.</CardDescription>
    </CardHeader>
    <CardContent>
      <form class="space-y-4" @submit.prevent="form.post('/cp/device')">
        <div class="space-y-2">
          <Label for="device-code">Code</Label>
          <Input
            id="device-code"
            v-model="form.code"
            class="font-mono tracking-widest uppercase"
            placeholder="XXXX-XXXX"
            autocomplete="off"
            required
            autofocus
          />
          <p v-if="form.errors.code" class="text-sm text-destructive">{{ form.errors.code }}</p>
        </div>
        <Button type="submit" class="w-full" :disabled="form.processing">Continue</Button>
      </form>
    </CardContent>
  </Card>
</template>
