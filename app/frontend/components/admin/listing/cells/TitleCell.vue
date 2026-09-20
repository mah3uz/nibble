<script setup lang="ts">
import { Link } from '@inertiajs/vue3'
import { computed } from 'vue'
import type { ListingCellValue } from '../types'

const props = defineProps<{ value: ListingCellValue; href: string | null }>()

const object = computed(() =>
  props.value && typeof props.value === 'object' && !Array.isArray(props.value) ? props.value : null,
)
const text = computed(() => object.value?.text ?? (props.value as string | number | null))
const subtitle = computed(() => object.value?.subtitle)
</script>

<template>
  <div class="min-w-0">
    <Link v-if="href" :href="href" class="text-gray-900 hover:text-black dark:text-gray-200 dark:hover:text-white">{{
      text
    }}</Link>
    <span v-else>{{ text }}</span>
    <div v-if="subtitle" class="truncate text-xs text-gray-500">{{ subtitle }}</div>
  </div>
</template>
