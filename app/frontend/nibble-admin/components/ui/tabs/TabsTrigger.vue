<script setup lang="ts">
import type { TabsTriggerProps } from 'reka-ui'
import type { HTMLAttributes } from 'vue'
import { reactiveOmit } from '@vueuse/core'
import { TabsTrigger, useForwardProps } from 'reka-ui'
import { cn } from '@/lib/utils'

const props = defineProps<TabsTriggerProps & { class?: HTMLAttributes['class'] }>()

const delegatedProps = reactiveOmit(props, 'class')

const forwardedProps = useForwardProps(delegatedProps)
</script>

<template>
  <TabsTrigger
    data-slot="tabs-trigger"
    :class="cn(
      'relative inline-flex translate-y-px cursor-pointer items-center gap-1.5 px-2 py-1 whitespace-nowrap outline-none hover:text-gray-600 focus-visible:rounded-lg focus-visible:focus-outline disabled:pointer-events-none disabled:opacity-50 data-active:text-gray-900 dark:hover:text-gray-400 dark:data-active:text-gray-200 [&_svg]:pointer-events-none [&_svg]:shrink-0 [&_svg:not([class*=size-])]:size-4',
      'after:absolute after:inset-x-0 after:bottom-0 after:h-px after:rounded-full after:bg-black after:opacity-0 after:transition-opacity data-active:after:opacity-100 dark:after:bg-white',
      props.class,
    )"
    v-bind="forwardedProps"
  >
    <slot />
  </TabsTrigger>
</template>
