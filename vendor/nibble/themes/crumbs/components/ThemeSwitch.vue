<script setup lang="ts">
import { onMounted, ref } from 'vue'

const STORAGE_KEY = 'crumbs-theme'
const dark = ref(false)

onMounted(() => {
  const saved = localStorage.getItem(STORAGE_KEY)
  dark.value = saved ? saved === 'dark' : window.matchMedia('(prefers-color-scheme: dark)').matches
  if (saved) document.documentElement.dataset.theme = saved
})

function toggle() {
  dark.value = !dark.value
  const theme = dark.value ? 'dark' : 'light'
  document.documentElement.dataset.theme = theme
  localStorage.setItem(STORAGE_KEY, theme)
}
</script>

<template>
  <button
    type="button"
    role="switch"
    aria-label="Lights"
    :aria-checked="!dark"
    :title="dark ? 'Turn the lights on' : 'Turn the lights off'"
    class="flex size-12 shrink-0 items-center justify-center hover:text-accent"
    @click="toggle"
  >
    <svg
      v-if="dark"
      class="size-6"
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      stroke-width="2"
      aria-hidden="true"
    >
      <path d="M21 12.8A9 9 0 1 1 11.2 3a7 7 0 0 0 9.8 9.8Z" />
    </svg>
    <svg
      v-else
      class="size-6"
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      stroke-width="2"
      aria-hidden="true"
    >
      <circle cx="12" cy="12" r="4" />
      <path d="M12 2v2m0 16v2M4.9 4.9l1.4 1.4m11.4 11.4 1.4 1.4M2 12h2m16 0h2M4.9 19.1l1.4-1.4M17.7 6.3l1.4-1.4" />
    </svg>
  </button>
</template>
