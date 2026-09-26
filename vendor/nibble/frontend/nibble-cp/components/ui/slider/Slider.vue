<script setup lang="ts">
import type { SliderRootEmits, SliderRootProps } from 'reka-ui'
import type { HTMLAttributes } from 'vue'
import { reactiveOmit } from '@vueuse/core'
import {
  SliderRange,
  SliderRoot,
  SliderThumb,
  SliderTrack,
  useForwardPropsEmits,
} from 'reka-ui'
import { cn } from '@/lib/utils'

const props = defineProps<SliderRootProps & { class?: HTMLAttributes['class']; thumbLabel?: string }>()

const emits = defineEmits<SliderRootEmits>()

const delegatedProps = reactiveOmit(props, 'class', 'thumbLabel')

const forwarded = useForwardPropsEmits(delegatedProps, emits)
</script>

<template>
  <SliderRoot
    data-slot="slider"
    v-bind="forwarded"
    :class="cn('relative flex h-5 w-full touch-none items-center select-none data-disabled:opacity-50', props.class)"
  >
    <SliderTrack
      data-slot="slider-track"
      class="relative h-2 grow overflow-hidden rounded-full bg-gray-300/80 dark:bg-gray-800"
    >
      <SliderRange data-slot="slider-range" class="absolute h-full rounded-full bg-gray-900 dark:bg-gray-200" />
    </SliderTrack>
    <SliderThumb
      v-for="(_, index) in modelValue ?? defaultValue ?? [0]"
      :key="index"
      data-slot="slider-thumb"
      :aria-label="thumbLabel"
      class="block size-5 cursor-grab rounded-full border-2 border-gray-900 bg-white shadow-ui-md transition-[box-shadow] outline-none hover:bg-gray-50 focus-visible:focus-outline active:cursor-grabbing dark:border-gray-200 dark:bg-gray-400"
    />
  </SliderRoot>
</template>
