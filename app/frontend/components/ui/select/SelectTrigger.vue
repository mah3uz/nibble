<script setup lang="ts">
import type { SelectTriggerProps } from 'reka-ui'

import type { HTMLAttributes } from 'vue'
import { ChevronDownIcon } from '@lucide/vue'
import { reactiveOmit } from '@vueuse/core'
import { SelectIcon, SelectTrigger, useForwardProps } from 'reka-ui'
import { cn } from '@/lib/utils'

const props = withDefaults(
  defineProps<SelectTriggerProps & { class?: HTMLAttributes['class'], size?: 'sm' | 'default' }>(),
  { size: 'default' },
)

const delegatedProps = reactiveOmit(props, 'class', 'size')
const forwardedProps = useForwardProps(delegatedProps)
</script>

<template>
  <SelectTrigger
    data-slot="select-trigger"
    :data-size="size"
    v-bind="forwardedProps"
    :class="cn(
      'flex w-full cursor-pointer items-center justify-between gap-1.5 rounded-lg border border-gray-300 bg-linear-to-b from-white to-gray-50 px-4 text-base whitespace-nowrap text-gray-900 antialiased shadow-ui-sm outline-none select-none focus-visible:focus-outline data-placeholder:text-gray-500 data-[size=default]:h-10 data-[size=sm]:h-8 data-[size=sm]:px-3 data-[size=sm]:text-sm disabled:cursor-not-allowed disabled:opacity-50 aria-invalid:border-destructive dark:border-gray-700 dark:from-gray-850 dark:to-gray-900 dark:text-gray-300 dark:shadow-ui-md *:data-[slot=select-value]:gap-1.5 *:data-[slot=select-value]:line-clamp-1 *:data-[slot=select-value]:flex *:data-[slot=select-value]:items-center [&_svg]:pointer-events-none [&_svg]:shrink-0 [&_svg:not([class*=size-])]:size-4 [&_svg:not([class*=text-])]:text-gray-400',
      props.class,
    )"
  >
    <slot />
    <SelectIcon as-child>
      <ChevronDownIcon class="text-muted-foreground size-4 pointer-events-none" />
    </SelectIcon>
  </SelectTrigger>
</template>
