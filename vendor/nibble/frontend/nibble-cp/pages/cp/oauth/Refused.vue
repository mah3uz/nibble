<script setup lang="ts">
import { Link } from '@inertiajs/vue3'
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card'

defineProps<{ message: string }>()
</script>

<template>
  <Card>
    <CardHeader>
      <CardTitle>Can't connect this app</CardTitle>
      <CardDescription>{{ message }}</CardDescription>
    </CardHeader>
    <CardContent>
      <Link href="/cp" class="text-sm text-muted-foreground hover:underline">Go to the Control Plane</Link>
    </CardContent>
  </Card>
</template>
