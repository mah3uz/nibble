<script setup lang="ts">
import { Card, CardDescription, CardHeader, CardTitle } from '@/components/ui/card'

defineProps<{ approved: boolean; name?: string }>()
</script>

<template>
  <Card>
    <CardHeader>
      <CardTitle>{{ approved ? `${name ?? 'The app'} is connected` : 'Not connected' }}</CardTitle>
      <CardDescription>
        {{
          approved
            ? 'Go back to the app to carry on. You can close this page.'
            : 'Nothing was shared. You can close this page.'
        }}
      </CardDescription>
    </CardHeader>
  </Card>
</template>
