<script setup lang="ts">
import type { HTMLAttributes } from 'vue'
import { DialogClose } from 'reka-ui'
import { cn } from '@/lib/utils'
import { Button } from '@/components/ui/button'

const props = withDefaults(defineProps<{
  class?: HTMLAttributes['class']
  showCloseButton?: boolean
}>(), {
  showCloseButton: false,
})
</script>

<template>
  <div
    data-slot="dialog-footer"
    :class="cn('flex flex-col gap-3 px-1 pt-3 pb-1 sm:flex-row sm:items-center sm:justify-end', props.class)"
  >
    <DialogClose v-if="showCloseButton" as-child>
      <Button variant="ghost">
        Cancel
      </Button>
    </DialogClose>
    <slot />
  </div>
</template>
