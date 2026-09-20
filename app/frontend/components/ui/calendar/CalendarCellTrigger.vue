<script lang="ts" setup>
import type { CalendarCellTriggerProps } from 'reka-ui'
import type { HTMLAttributes } from 'vue'
import { reactiveOmit } from '@vueuse/core'
import { CalendarCellTrigger, useForwardProps } from 'reka-ui'
import { cn } from '@/lib/utils'

const props = withDefaults(defineProps<CalendarCellTriggerProps & { class?: HTMLAttributes['class'] }>(), {
  as: 'button',
})

const delegatedProps = reactiveOmit(props, 'class')

const forwardedProps = useForwardProps(delegatedProps)
</script>

<template>
  <CalendarCellTrigger
    data-slot="calendar-cell-trigger"
    :class="cn(
      'relative flex size-8 cursor-pointer items-center justify-center rounded-lg p-0 text-sm font-normal whitespace-nowrap text-gray-925 outline-hidden focus-visible:focus-outline dark:text-white',
      'data-outside-view:text-gray-400 dark:data-outside-view:text-gray-600',
      'data-selected:bg-gray-800! data-selected:text-white dark:data-selected:bg-gray-200! dark:data-selected:text-gray-925',
      'hover:bg-gray-100 data-highlighted:bg-gray-200 dark:hover:bg-black dark:data-highlighted:bg-black',
      'data-disabled:pointer-events-none data-disabled:text-gray-400 dark:data-disabled:text-gray-600',
      'data-unavailable:pointer-events-none data-unavailable:text-gray-925/30 data-unavailable:line-through',
      'before:absolute before:top-[3px] before:hidden before:h-1 before:w-1 before:rounded-lg before:bg-white data-today:before:block data-today:before:bg-green-500',
      props.class,
    )"
    v-bind="forwardedProps"
  >
    <slot />
  </CalendarCellTrigger>
</template>
