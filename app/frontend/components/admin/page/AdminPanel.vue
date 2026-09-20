<script setup lang="ts">
import { useSlots } from 'vue'

defineProps<{ title?: string; description?: string; flush?: boolean; fill?: boolean; bare?: boolean }>()
const slots = useSlots()
</script>

<template>
  <section
    :class="[
      '@container/panel relative w-full rounded-2xl bg-gray-150 p-1.75 has-[>header]:pt-0 max-[600px]:p-1.25 dark:bg-gray-950/35 dark:inset-shadow-2xs dark:inset-shadow-black',
      fill ? 'flex h-full flex-col' : 'mb-6',
    ]"
  >
    <header
      v-if="title || description || slots.actions"
      class="flex min-h-11 items-center justify-between gap-3 py-3 ps-4.5 pe-1"
    >
      <div>
        <h2 v-if="title" class="flex items-center gap-2 text-sm font-medium text-gray-900 antialiased dark:text-white">
          {{ title }}
        </h2>
        <p v-if="description" class="text-sm text-gray-600/90 dark:text-gray-400">{{ description }}</p>
      </div>
      <div v-if="slots.actions" class="-my-1.5 flex flex-wrap items-center gap-2 sm:gap-3"><slot name="actions" /></div>
    </header>
    <slot v-if="bare" />
    <div
      v-else
      :class="[
        'dark:ring-x-0 dark:ring-b-0 rounded-xl bg-white shadow-ui-md ring ring-gray-200 dark:bg-gray-850 dark:ring-gray-700/80',
        flush ? 'overflow-hidden' : 'space-y-2 px-4 py-5 sm:px-4.5',
        fill && 'min-h-0 flex-1 overflow-y-auto',
      ]"
    >
      <slot />
    </div>
    <footer v-if="slots.footer" class="flex flex-wrap px-4.5 pt-2.5 pb-1.5 antialiased md:pt-3">
      <slot name="footer" />
    </footer>
  </section>
</template>
