<script setup lang="ts">
import type { AlertDialogContentEmits, AlertDialogContentProps } from 'reka-ui'
import type { HTMLAttributes } from 'vue'
import { reactiveOmit } from '@vueuse/core'
import {
  AlertDialogContent,
  AlertDialogOverlay,
  AlertDialogPortal,
  injectDialogRootContext,
  useForwardPropsEmits,
} from 'reka-ui'
import { useSlots } from 'vue'
import { useLayerZIndex } from '@/lib/layers'
import { cn } from '@/lib/utils'
import { MODAL_CARD_CLASS, MODAL_FRAME_CLASS, MODAL_OVERLAY_CLASS, splitFooter } from '@/components/ui/dialog/modalParts'
import AlertDialogFooter from './AlertDialogFooter.vue'

defineOptions({
  inheritAttrs: false,
})

const props = withDefaults(
  defineProps<AlertDialogContentProps & {
    class?: HTMLAttributes['class']
    size?: 'default' | 'sm'
  }>(),
  {
    size: 'default',
  },
)
const emits = defineEmits<AlertDialogContentEmits>()

const delegatedProps = reactiveOmit(props, 'class', 'size')

const forwarded = useForwardPropsEmits(delegatedProps, emits)
const zIndex = useLayerZIndex(injectDialogRootContext().open)
const slots = useSlots()
const Body = () => splitFooter(slots.default?.(), AlertDialogFooter).body
const Footer = () => splitFooter(slots.default?.(), AlertDialogFooter).footer
</script>

<template>
  <AlertDialogPortal>
    <AlertDialogOverlay data-slot="alert-dialog-overlay" :style="{ zIndex }" :class="MODAL_OVERLAY_CLASS" />
    <AlertDialogContent
      data-slot="alert-dialog-content"
      :data-size="size"
      v-bind="{ ...$attrs, ...forwarded }"
      :style="{ zIndex: zIndex + 1 }"
      :class="cn(MODAL_FRAME_CLASS, 'group/alert-dialog-content data-[size=sm]:sm:max-w-md', props.class)"
    >
      <div data-slot="alert-dialog-card" :class="MODAL_CARD_CLASS">
        <Body />
      </div>
      <Footer />
    </AlertDialogContent>
  </AlertDialogPortal>
</template>
