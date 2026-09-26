<script setup lang="ts">
import { router, usePage } from '@inertiajs/vue3'
import { computed, onBeforeUnmount, onMounted, ref } from 'vue'

type Update = { type: 'nibble:preview'; url: string; entry_json: string; token: string }

const page = usePage<{ preview?: { label: string; edit_url?: string } | null }>()
const preview = computed(() => page.props.preview)
const updating = ref(false)

const editor = () => (typeof window === 'undefined' ? null : window.parent !== window ? window.parent : window.opener)
const tell = (type: string) => editor()?.postMessage({ type }, window.location.origin)

// The editor sends each change here, so the page updates in place instead of reloading blank.
function receive(event: MessageEvent<Update>) {
  if (event.origin !== window.location.origin || event.data?.type !== 'nibble:preview') return
  const { url, entry_json, token } = event.data
  router.post(
    url,
    { entry_json, authenticity_token: token },
    {
      preserveScroll: true,
      preserveState: true,
      replace: true,
      viewTransition: true,
      onStart: () => (updating.value = true),
      onFinish: () => (updating.value = false),
    },
  )
}

const leave = () => tell('nibble:preview-left')

onMounted(() => {
  if (!preview.value) return
  window.addEventListener('message', receive)
  window.addEventListener('pagehide', leave)
  tell('nibble:preview-ready')
})
onBeforeUnmount(() => {
  window.removeEventListener('message', receive)
  window.removeEventListener('pagehide', leave)
})
</script>

<template>
  <div v-if="preview" role="status" data-nibble-preview class="nibble-preview-ribbon" :class="{ updating }">
    <div class="band">
      <slot :preview="preview">
        <span class="title"><span class="dot" aria-hidden="true" />Preview</span>
        <span class="label">{{ preview.label }}</span>
        <a v-if="preview.edit_url" :href="preview.edit_url" class="edit">Edit</a>
      </slot>
    </div>
  </div>
</template>

<style scoped>
.nibble-preview-ribbon {
  position: fixed;
  top: 0;
  right: 0;
  z-index: 2147483000;
  width: 190px;
  height: 190px;
  overflow: hidden;
  pointer-events: none;
}

.band {
  position: absolute;
  top: 44px;
  right: -64px;
  width: 270px;
  padding: 7px 0 8px;
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 1px;
  transform: rotate(45deg);
  color: #fff;
  font-family: ui-sans-serif, system-ui, sans-serif;
  text-align: center;
  background: linear-gradient(90deg, #f59e0b, #f43f5e 55%, #d946ef);
  border-block: 1px solid rgb(255 255 255 / 0.45);
  box-shadow:
    0 6px 18px rgb(0 0 0 / 0.28),
    inset 0 1px 0 rgb(255 255 255 / 0.25);
  text-shadow: 0 1px 1px rgb(0 0 0 / 0.25);
}

.title {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  font-size: 12px;
  font-weight: 700;
  letter-spacing: 0.16em;
  text-transform: uppercase;
}

.label {
  max-width: 150px;
  font-size: 9.5px;
  font-weight: 500;
  line-height: 1.25;
  opacity: 0.92;
}

.edit {
  margin-top: 2px;
  font-size: 10px;
  font-weight: 600;
  color: inherit;
  text-decoration: underline;
  pointer-events: auto;
}

.dot {
  width: 6px;
  height: 6px;
  border-radius: 9999px;
  background: #fff;
  box-shadow: 0 0 0 0 rgb(255 255 255 / 0.7);
}

.updating .dot {
  animation: nibble-preview-pulse 0.9s ease-out infinite;
}

@keyframes nibble-preview-pulse {
  to {
    box-shadow: 0 0 0 7px rgb(255 255 255 / 0);
  }
}

@media (prefers-reduced-motion: reduce) {
  .updating .dot {
    animation: none;
  }
}
</style>
