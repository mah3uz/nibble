<script lang="ts" setup>
import type { CalendarNextProps } from 'reka-ui'

import type { HTMLAttributes } from 'vue'
import { ChevronRightIcon } from '@lucide/vue'
import { reactiveOmit } from '@vueuse/core'
import { CalendarNext, useForwardProps } from 'reka-ui'
import { cn } from '@/lib/utils'

const props = defineProps<CalendarNextProps & { class?: HTMLAttributes['class'] }>()

const delegatedProps = reactiveOmit(props, 'class')

const forwardedProps = useForwardProps(delegatedProps)
</script>

<template>
  <CalendarNext
    data-slot="calendar-next-button"
    :class="cn(
      'inline-flex size-7.5 cursor-pointer items-center justify-center rounded-md text-gray-925 hover:bg-gray-50 active:scale-90 dark:text-white dark:hover:bg-gray-925',
      props.class,
    )"
    v-bind="forwardedProps"
  >
    <slot>
      <ChevronRightIcon class="cn-rtl-flip size-4" />
    </slot>
  </CalendarNext>
</template>
