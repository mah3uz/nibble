<script setup lang="ts">
import type { AcceptableValue } from 'reka-ui'

import type { HTMLAttributes } from 'vue'
import { ChevronDownIcon } from '@lucide/vue'
import { reactiveOmit, useVModel } from '@vueuse/core'
import { cn } from '@/lib/utils'

defineOptions({
  inheritAttrs: false,
})

const props = defineProps<{
  modelValue?: AcceptableValue | AcceptableValue[]
  class?: HTMLAttributes['class']
  size?: 'sm' | 'default'
}>()

const emit = defineEmits<{
  'update:modelValue': [value: AcceptableValue]
}>()

const modelValue = useVModel(props, 'modelValue', emit, {
  passive: true,
  defaultValue: '',
})

const delegatedProps = reactiveOmit(props, 'class', 'size')
</script>

<template>
  <div
    :class="cn('group/native-select relative w-fit has-[select:disabled]:opacity-50', props.class)"
    data-slot="native-select-wrapper"
    :data-size="props.size ?? 'default'"
  >
    <select
      v-bind="{ ...$attrs, ...delegatedProps }"
      v-model="modelValue"
      data-slot="native-select"
      class="h-10 w-full min-w-0 cursor-pointer appearance-none rounded-lg border border-gray-300 bg-linear-to-b from-white to-gray-50 py-0 pr-10 pl-4 text-base text-gray-900 antialiased shadow-ui-sm outline-none select-none focus-visible:focus-outline data-[size=sm]:h-8 data-[size=sm]:pr-8 data-[size=sm]:pl-3 data-[size=sm]:text-sm aria-invalid:border-destructive disabled:pointer-events-none disabled:cursor-not-allowed dark:border-gray-700 dark:from-gray-850 dark:to-gray-900 dark:text-gray-300 dark:shadow-ui-md"
      :data-size="props.size ?? 'default'"
    >
      <slot />
    </select>
    <ChevronDownIcon class="text-gray-400 top-1/2 right-3 size-4 -translate-y-1/2 pointer-events-none absolute select-none" aria-hidden="true" data-slot="native-select-icon" />
  </div>
</template>
