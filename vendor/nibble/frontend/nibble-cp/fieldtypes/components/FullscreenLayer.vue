<script setup lang="ts">
import { computed, inject, provide, ref } from 'vue'
import CpIcon from '@/components/cp/icons/CpIcon.vue'
import { Button } from '@/components/ui/button'
import { Dialog, DialogClose, DialogContent, DialogDescription, DialogTitle } from '@/components/ui/dialog'
import { Toaster } from '@/components/ui/sonner'
import { FULLSCREEN_LAYER } from '../display'
import { useLayerToaster } from '../rows'

defineProps<{ title: string }>()
const open = defineModel<boolean>('open', { default: false })
const target = ref<HTMLElement | null>(null)
const toasterId = useLayerToaster(open)

const outer = inject(FULLSCREEN_LAYER, null)
provide(
  FULLSCREEN_LAYER,
  computed(() => open.value || !!outer?.value),
)
</script>

<template>
  <Dialog v-model:open="open">
    <DialogContent
      class="top-0 left-0 h-dvh max-w-none translate-x-0 translate-y-0 rounded-none bg-gray-100 p-0 sm:max-w-none dark:bg-gray-850"
      card-class="max-h-none gap-0 overflow-hidden rounded-none border-0 bg-transparent p-0 shadow-none dark:bg-transparent dark:shadow-none dark:inset-shadow-none"
      :show-close-button="false"
    >
      <header
        class="flex h-12 shrink-0 items-center justify-between gap-4 bg-gray-50 px-4 shadow-ui-lg dark:border-b dark:border-white/10 dark:bg-gray-925 dark:shadow-none"
      >
        <DialogTitle class="truncate text-[0.9375rem] font-medium text-gray-925 dark:text-white">{{
          title
        }}</DialogTitle>
        <DialogDescription class="sr-only"
          >Editing {{ title }} in full screen. Press Escape to return.</DialogDescription
        >
        <DialogClose as-child>
          <Button type="button" variant="outline" size="sm" class="px-2.5" aria-label="Close full screen">
            <CpIcon name="fullscreen-close" class="size-3.5" />
          </Button>
        </DialogClose>
      </header>
      <div class="min-h-0 flex-1 overflow-auto px-4 py-6">
        <div
          :ref="(el) => (target = el as HTMLElement | null)"
          class="mx-auto max-w-[65rem] rounded-lg bg-white p-6 shadow-ui-md dark:bg-gray-900 dark:shadow-none"
        />
      </div>
      <Toaster :id="toasterId" rich-colors />
    </DialogContent>
  </Dialog>
  <Teleport :to="target ?? 'body'" :disabled="!target">
    <slot />
  </Teleport>
</template>
