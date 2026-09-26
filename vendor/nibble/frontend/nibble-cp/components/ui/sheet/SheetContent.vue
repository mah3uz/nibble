<script setup lang="ts">
import type { DialogContentEmits, DialogContentProps } from 'reka-ui'

import type { HTMLAttributes } from 'vue'
import { XIcon } from '@lucide/vue'
import { reactiveOmit } from '@vueuse/core'
import {
  DialogClose,
  DialogContent,
  DialogPortal,
  injectDialogRootContext,
  useForwardPropsEmits,
} from 'reka-ui'
import { useWindowSize } from '@vueuse/core'
import { computed } from 'vue'
import { useLayerZIndex } from '@/lib/layers'
import { stackOffsets, useStack, type StackSize } from '@/lib/stacks'
import { cn } from '@/lib/utils'
import { Button } from '@/components/ui/button'
import SheetOverlay from './SheetOverlay.vue'

interface SheetContentProps extends DialogContentProps {
  class?: HTMLAttributes['class']
  side?: 'top' | 'right' | 'bottom' | 'left'
  showCloseButton?: boolean
  size?: StackSize
}

defineOptions({
  inheritAttrs: false,
})

const props = withDefaults(defineProps<SheetContentProps>(), {
  side: 'right',
  showCloseButton: true,
})
const emits = defineEmits<DialogContentEmits>()

const delegatedProps = reactiveOmit(props, 'class', 'side', 'showCloseButton', 'size')

const forwarded = useForwardPropsEmits(delegatedProps, emits)
const { open } = injectDialogRootContext()
const zIndex = useLayerZIndex(open)
const { depth, count, hoveredDepth } = useStack(open)
const { width: windowWidth } = useWindowSize()
const offsets = computed(() =>
  stackOffsets({ depth: Math.max(depth.value, 1), count: Math.max(count.value, 1), size: props.size, windowWidth: windowWidth.value }),
)
const isStacked = computed(() => props.side === 'right')
const peeking = computed(() => hoveredDepth.value === depth.value && depth.value < count.value)
const contentStyle = computed(() =>
  isStacked.value
    ? { zIndex: zIndex.value + 1, left: `${offsets.value.left}px`, transform: peeking.value ? 'translateX(-1rem)' : undefined }
    : { zIndex: zIndex.value + 1 },
)
</script>

<template>
  <DialogPortal>
    <SheetOverlay :style="{ zIndex }" />
    <div
      v-if="isStacked && open && offsets.left > 0"
      aria-hidden="true"
      class="pointer-events-auto fixed inset-y-0 cursor-pointer"
      :style="{ zIndex: zIndex + 1, left: `${offsets.left - offsets.offset}px`, width: `${offsets.offset}px` }"
      @mouseenter="hoveredDepth = depth - 1"
      @mouseleave="hoveredDepth = null"
    />
    <DialogContent
      data-slot="sheet-content"
      :data-side="side"
      :style="contentStyle"
      :class="cn('fixed flex flex-col overflow-hidden rounded-xl bg-white text-sm text-gray-900 shadow-[0_8px_5px_-6px_rgba(0,0,0,0.1),_0_3px_8px_0_rgba(0,0,0,0.02),_0_30px_22px_-22px_rgba(39,39,42,0.15)] transition-[transform,opacity] duration-200 ease-out outline-none dark:bg-gray-900 dark:text-gray-200 dark:shadow-[0_5px_20px_rgba(0,0,0,.5)] data-[side=right]:inset-y-2 data-[side=right]:right-0 sm:data-[side=right]:right-1.5 data-[side=left]:inset-y-2 data-[side=left]:left-1.5 data-[side=left]:w-[calc(100%-1rem)] data-[side=left]:sm:max-w-md data-[side=top]:inset-x-2 data-[side=top]:top-2 data-[side=bottom]:inset-x-2 data-[side=bottom]:bottom-2 data-open:animate-in data-open:fade-in-0 data-closed:animate-out data-closed:fade-out-0 data-[side=right]:data-open:slide-in-from-right-[10%] data-[side=right]:data-closed:slide-out-to-right-[10%] data-[side=left]:data-open:slide-in-from-left-[10%] data-[side=left]:data-closed:slide-out-to-left-[10%]', props.class)"
      v-bind="{ ...$attrs, ...forwarded }"
    >
      <slot />

      <DialogClose
        v-if="showCloseButton"
        data-slot="sheet-close"
        as-child
      >
        <Button variant="ghost" class="absolute top-2 right-2" size="icon">
          <XIcon />
          <span class="sr-only">Close</span>
        </Button>
      </DialogClose>
    </DialogContent>
  </DialogPortal>
</template>
