<script setup lang="ts">
import { ref } from 'vue'
import { Dialog, DialogContent, DialogDescription, DialogTitle } from '@/components/ui/dialog'

defineProps<{ title: string }>()
const open = defineModel<boolean>('open', { default: false })
const target = ref<HTMLElement | null>(null)
</script>

<template>
  <Dialog v-model:open="open">
    <DialogContent
      class="top-0 left-0 h-dvh max-w-none translate-x-0 translate-y-0 rounded-none sm:max-w-none"
      card-class="max-h-none"
    >
      <DialogTitle class="sr-only">{{ title }}</DialogTitle>
      <DialogDescription class="sr-only">Editing {{ title }} in full screen. Press Escape to return.</DialogDescription>
      <div :ref="(el) => (target = el as HTMLElement | null)" class="min-h-0 flex-1" />
    </DialogContent>
  </Dialog>
  <Teleport :to="target ?? 'body'" :disabled="!target">
    <slot />
  </Teleport>
</template>
