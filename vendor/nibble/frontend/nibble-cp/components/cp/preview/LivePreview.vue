<script setup lang="ts">
import { ExternalLink, X } from '@lucide/vue'
import { useDebounceFn } from '@vueuse/core'
import { computed, nextTick, onBeforeUnmount, onMounted, ref, watch } from 'vue'
import { Button } from '@/components/ui/button'
import { ResizableHandle, ResizablePanel, ResizablePanelGroup } from '@/components/ui/resizable'
import DeviceToggle, { DEVICE_SIZES, type Device } from './DeviceToggle.vue'

const props = defineProps<{ open: boolean; url: string | null; values: Record<string, unknown> }>()
const emit = defineEmits<{ 'update:open': [boolean]; 'update:poppedOut': [boolean] }>()

const FRAME = 'nibble-live-preview'
const POPUP = 'nibble-live-preview-window'

const device = ref<Device>('responsive')
const popup = ref<Window | null>(null)
const poppedOut = computed(() => !!popup.value && !popup.value.closed)
watch(poppedOut, (value) => emit('update:poppedOut', value))

let closeCheck: number | undefined
watch(popup, (win) => {
  if (closeCheck) window.clearInterval(closeCheck)
  if (!win) return
  closeCheck = window.setInterval(() => {
    if (win.closed) popup.value = null
  }, 500)
})

// The preview page says when it can take changes in place; until then, and after it navigates away, it is reloaded.
const live = ref<MessageEventSource | null>(null)
function onMessage(event: MessageEvent) {
  if (event.origin !== window.location.origin) return
  if (event.data?.type === 'nibble:preview-ready') live.value = event.source
  if (event.data?.type === 'nibble:preview-left' && live.value === event.source) live.value = null
}
onMounted(() => window.addEventListener('message', onMessage))

const token = () => document.querySelector<HTMLMetaElement>('meta[name=csrf-token]')?.content ?? ''

function target() {
  if (poppedOut.value) return popup.value
  return document.querySelector<HTMLIFrameElement>(`iframe[name="${FRAME}"]`)?.contentWindow ?? null
}

function render() {
  if (!props.url || !props.open) return
  const win = target()
  if (win && live.value === win) {
    win.postMessage(
      { type: 'nibble:preview', url: props.url, entry_json: JSON.stringify(props.values), token: token() },
      window.location.origin,
    )
    return
  }
  live.value = null
  const form = Object.assign(document.createElement('form'), {
    method: 'post',
    action: props.url,
    target: poppedOut.value ? POPUP : FRAME,
  })
  const fields = {
    authenticity_token: token(),
    entry_json: JSON.stringify(props.values),
  }
  for (const [name, value] of Object.entries(fields))
    form.appendChild(Object.assign(document.createElement('input'), { type: 'hidden', name, value }))
  document.body.appendChild(form)
  form.submit()
  form.remove()
}
const refresh = useDebounceFn(render, 600)
watch(() => props.values, refresh, { deep: true })
watch(
  () => props.open,
  (open) => open && nextTick(render),
  { immediate: true },
)

function popOut() {
  if (!props.url) return
  popup.value = window.open('about:blank', POPUP)
  render()
}

function popIn() {
  popup.value?.close()
  popup.value = null
  live.value = null
  nextTick(render)
}

defineExpose({ popIn })

function close() {
  popup.value?.close()
  popup.value = null
  emit('update:open', false)
}

function onKeydown(event: KeyboardEvent) {
  if (event.key === 'Escape') close()
}
// Not a reka Dialog, so it has to lock page scroll itself.
watch(
  () => props.open && !poppedOut.value,
  (covering) => {
    if (covering) {
      window.addEventListener('keydown', onKeydown)
      document.body.style.overflow = 'hidden'
    } else {
      window.removeEventListener('keydown', onKeydown)
      document.body.style.overflow = ''
    }
  },
)
onBeforeUnmount(() => {
  window.removeEventListener('message', onMessage)
  window.removeEventListener('keydown', onKeydown)
  document.body.style.overflow = ''
  if (closeCheck) window.clearInterval(closeCheck)
  popup.value?.close()
})

const frameStyle = computed(() => {
  if (device.value === 'responsive') return {}
  const size = DEVICE_SIZES[device.value]
  return { width: `${size.width}px`, height: size.height ? `${size.height}px` : '100%' }
})
const storage = typeof window === 'undefined' ? undefined : window.sessionStorage
</script>

<template>
  <Teleport to="body">
    <div v-if="open && !poppedOut" class="fixed inset-0 z-50 flex flex-col bg-background">
      <div class="flex h-13 shrink-0 items-center justify-between gap-2 border-b py-2 pr-4 pl-7">
        <span class="text-base font-medium text-foreground/90">Live Preview</span>
        <div class="flex items-center gap-2">
          <Button type="button" variant="outline" size="sm" @click="popOut"> <ExternalLink />Pop out </Button>
          <DeviceToggle v-model="device" />
          <slot name="actions" />
          <Button type="button" variant="ghost" size="icon" aria-label="Close live preview" @click="close">
            <X />
          </Button>
        </div>
      </div>

      <ResizablePanelGroup direction="horizontal" class="flex-1" auto-save-id="live-preview-split" :storage="storage">
        <!-- SplitterPanel sets overflow: hidden inline, so scrolling lives in an inner wrapper. -->
        <ResizablePanel :default-size="25" :min-size="18">
          <div class="h-full space-y-4 overflow-y-auto p-4">
            <slot name="fields" :wide="false" />
          </div>
        </ResizablePanel>
        <ResizableHandle with-handle />
        <ResizablePanel :default-size="75">
          <div
            class="flex h-full items-center justify-center overflow-auto p-4"
            :class="device === 'responsive' ? '' : 'bg-[oklch(0.552_0.016_285.938)]'"
          >
            <iframe
              v-if="url"
              :name="FRAME"
              title="Live preview"
              class="bg-white"
              :class="device === 'responsive' ? 'h-full w-full' : 'rounded shadow-lg'"
              :style="frameStyle"
            />
          </div>
        </ResizablePanel>
      </ResizablePanelGroup>
    </div>
  </Teleport>
</template>
