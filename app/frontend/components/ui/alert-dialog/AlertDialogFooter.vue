<script setup lang="ts">
import type { HTMLAttributes } from 'vue'
import { cn } from '@/lib/utils'

const props = defineProps<{
  class?: HTMLAttributes['class']
}>()
</script>

<template>
  <div
    data-slot="alert-dialog-footer"
    :class="
      cn(
        'flex flex-col gap-3 px-1 pt-3 pb-1 sm:flex-row sm:items-center sm:justify-end',
        props.class,
      )
    "
  >
    <slot />
  </div>
</template>
