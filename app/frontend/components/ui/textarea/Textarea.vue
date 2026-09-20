<script setup lang="ts">
import type { HTMLAttributes } from 'vue'
import { useVModel } from '@vueuse/core'
import { cn } from '@/lib/utils'

const props = defineProps<{
  class?: HTMLAttributes['class']
  defaultValue?: string | number
  modelValue?: string | number
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
  <textarea
    v-model="modelValue"
    data-slot="textarea"
    :class="cn('flex w-full min-h-30 resize-y appearance-none rounded-lg border border-gray-300 bg-white px-3 pt-2.5 pb-3 text-base text-gray-900 antialiased shadow-ui-sm outline-none placeholder:text-gray-500 focus-visible:focus-outline read-only:border-dashed disabled:cursor-not-allowed disabled:opacity-50 disabled:shadow-none aria-invalid:border-destructive dark:border-gray-700 dark:bg-gray-900 dark:text-gray-300 dark:placeholder:text-gray-400/85', props.class)"
  />
</template>
