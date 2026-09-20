<script setup lang="ts">
import type { HTMLAttributes } from 'vue'
import { cn } from '@/lib/utils'

const props = defineProps<{ class?: HTMLAttributes['class'] }>()
</script>

<template>
  <div
    data-slot="sheet-header"
    :class="cn('flex min-h-14 flex-col justify-center gap-0.5 rounded-t-xl border-b border-gray-300 ps-6 pe-14 py-2 dark:border-gray-950 dark:bg-gray-800', props.class)"
  >
    <slot />
  </div>
</template>
