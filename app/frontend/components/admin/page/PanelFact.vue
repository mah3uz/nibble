<script setup lang="ts">
defineProps<{ label: string; value: string | number }>()
</script>

<template>
  <span
    class="inline-flex items-stretch overflow-hidden rounded-md border border-gray-300 text-xs leading-6 text-gray-700 dark:border-gray-700 dark:text-gray-300"
  >
    <span class="px-2 font-medium">{{ label }}</span>
    <span class="border-s border-gray-300 bg-gray-50 px-2 tabular-nums dark:border-gray-700 dark:bg-gray-900">{{
      value
    }}</span>
  </span>
</template>
