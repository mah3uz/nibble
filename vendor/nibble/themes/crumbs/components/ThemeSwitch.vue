<script setup lang="ts">
import { onMounted, ref } from 'vue'

const LEGACY_KEY = 'crumbs-theme'
const dark = ref(false)

// The shell reads this cookie into <html data-theme>, so the next page arrives in the chosen register.
function remember(theme: string) {
  document.cookie = `nibble_theme=${theme}; path=/; max-age=31536000; samesite=lax`
  document.documentElement.dataset.theme = theme
}

onMounted(() => {
  const legacy = localStorage.getItem(LEGACY_KEY)
  if (legacy) {
    localStorage.removeItem(LEGACY_KEY)
    if (!document.documentElement.dataset.theme) remember(legacy)
  }
  const theme = document.documentElement.dataset.theme
  dark.value = theme ? theme === 'dark' : window.matchMedia('(prefers-color-scheme: dark)').matches
})

function toggle() {
  dark.value = !dark.value
  remember(dark.value ? 'dark' : 'light')
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
