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
import { useSlots } from 'vue'
import { useLayerZIndex } from '@/lib/layers'
import { cn } from '@/lib/utils'
import { Button } from '@/components/ui/button'
import DialogFooter from './DialogFooter.vue'
import DialogOverlay from './DialogOverlay.vue'
import { MODAL_CARD_CLASS, MODAL_FRAME_CLASS, splitFooter } from './modalParts'

defineOptions({
  inheritAttrs: false,
})

const props = withDefaults(defineProps<DialogContentProps & { class?: HTMLAttributes['class'], cardClass?: HTMLAttributes['class'], showCloseButton?: boolean }>(), {
  showCloseButton: true,
})
const emits = defineEmits<DialogContentEmits>()

const delegatedProps = reactiveOmit(props, 'class', 'cardClass', 'showCloseButton')

const forwarded = useForwardPropsEmits(delegatedProps, emits)
const zIndex = useLayerZIndex(injectDialogRootContext().open)
const slots = useSlots()
const Body = () => splitFooter(slots.default?.(), DialogFooter).body
const Footer = () => splitFooter(slots.default?.(), DialogFooter).footer
</script>

<template>
  <DialogPortal>
    <DialogOverlay :style="{ zIndex }" />
    <DialogContent
      data-slot="dialog-content"
      v-bind="{ ...$attrs, ...forwarded }"
      :style="{ zIndex: zIndex + 1 }"
      :class="cn(MODAL_FRAME_CLASS, props.class)"
    >
      <div data-slot="dialog-card" :class="cn(MODAL_CARD_CLASS, props.cardClass)">
        <Body />
        <DialogClose
          v-if="showCloseButton"
          data-slot="dialog-close"
          as-child
        >
          <Button variant="ghost" class="absolute top-2.5 right-2.5" size="icon-sm">
            <XIcon />
            <span class="sr-only">Close</span>
          </Button>
        </DialogClose>
      </div>
      <Footer />
    </DialogContent>
  </DialogPortal>
</template>
