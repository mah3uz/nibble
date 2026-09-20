<script setup lang="ts">
import type { HTMLAttributes } from 'vue'
import { cn } from '@/lib/utils'

const props = defineProps<{
  class?: HTMLAttributes['class']
}>()
</script>

<template>
  <p
    data-slot="field-description"
    :class="cn(
      'text-gray-600/90 dark:text-gray-400 text-left text-sm [[data-variant=legend]+&]:-mt-1.5 leading-normal font-normal [&_a]:underline [&_a:hover]:text-gray-700 group-has-data-horizontal/field:text-balance',
      'last:mt-0 nth-last-2:-mt-1',
      '[&>a]:underline [&>a]:underline-offset-4 [&>a:hover]:text-primary',
      props.class,
    )"
  >
    <slot />
  </p>
</template>
