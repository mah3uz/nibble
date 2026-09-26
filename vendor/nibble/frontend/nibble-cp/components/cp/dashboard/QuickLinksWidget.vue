<script setup lang="ts">
import { Link } from '@inertiajs/vue3'
import CpIcon from '@/components/cp/icons/CpIcon.vue'
import type { QuickLinksData } from './types'

defineProps<{ data: QuickLinksData }>()
</script>

<template>
  <div v-if="data.links.length" class="grid gap-1 p-2">
    <Link
      v-for="link in data.links"
      :key="link.url"
      :href="link.url"
      class="group flex items-start gap-3 rounded-lg px-2.5 py-2 transition-colors hover:bg-gray-50 dark:hover:bg-gray-900/60"
    >
      <span class="grid size-8 shrink-0 place-items-center rounded-lg bg-gray-100 dark:bg-gray-800">
        <CpIcon :name="link.icon" class="size-4 text-gray-600 dark:text-gray-300" />
      </span>
      <span class="min-w-0">
        <span class="block text-sm font-medium text-gray-900 group-hover:underline dark:text-white">{{
          link.label
        }}</span>
        <span class="block text-xs text-gray-500">{{ link.description }}</span>
      </span>
    </Link>
  </div>
  <p v-else class="px-4.5 py-8 text-center text-sm text-gray-500">No quick links available.</p>
</template>
