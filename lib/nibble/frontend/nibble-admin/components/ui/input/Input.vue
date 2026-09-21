<script setup lang="ts">
import type { HTMLAttributes } from 'vue'
import { useVModel } from '@vueuse/core'
import { cn } from '@/lib/utils'

const props = defineProps<{
  defaultValue?: string | number
  modelValue?: string | number
  class?: HTMLAttributes['class']
}>()

const emits = defineEmits<{
  (e: 'update:modelValue', payload: string | number): void
}>()

const modelValue = useVModel(props, 'modelValue', emits, {
  passive: true,
  defaultValue: props.defaultValue,
})
</script>

<template>
  <input
    v-model="modelValue"
    data-slot="input"
    :class="cn(
      'w-full min-w-0 block appearance-none rounded-lg border border-gray-300 bg-white px-3 py-2 h-10 text-base leading-[1.375rem] text-gray-925 antialiased shadow-ui-sm st-text-legibility outline-none placeholder:text-gray-500 focus-visible:focus-outline read-only:border-dashed disabled:pointer-events-none disabled:cursor-not-allowed disabled:opacity-50 disabled:shadow-none aria-invalid:border-destructive dark:border-gray-700 dark:bg-gray-900 dark:text-gray-300 dark:not-data-[slot=input-group-control]:inset-shadow-2xs dark:inset-shadow-black dark:placeholder:text-gray-400/85 file:inline-flex file:h-6 file:border-0 file:bg-transparent file:text-sm file:font-medium file:text-foreground',
      props.class,
    )"
  >
</template>
