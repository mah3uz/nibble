<script setup lang="ts">
import { X } from '@lucide/vue'
import { Button } from '@/components/ui/button'
import type { ListingAction } from './types'

defineProps<{ count: number; actions: ListingAction[] }>()
const emit = defineEmits<{ run: [action: ListingAction]; clear: [] }>()
</script>

<template>
  <div v-if="count > 0" class="fixed inset-x-0 bottom-6 z-20 flex justify-center">
    <div class="flex items-center gap-3 rounded-full border bg-popover px-4 py-2 text-popover-foreground shadow-lg">
      <span class="text-sm font-medium">{{ count }} selected</span>
      <Button
        v-for="action in actions"
        :key="action.handle"
        size="sm"
        :variant="action.dangerous ? 'destructive' : 'outline'"
        @click="emit('run', action)"
        >{{ action.label }}</Button
      >
      <Button size="icon" variant="ghost" aria-label="Clear selection" @click="emit('clear')"><X /></Button>
    </div>
  </div>
</template>
