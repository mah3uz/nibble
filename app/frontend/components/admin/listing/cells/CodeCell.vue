<script setup lang="ts">
defineProps<{ value: string | number | null }>()
</script>

<template>
  <span class="block max-w-md truncate font-mono text-xs" :title="String(value ?? '')">{{ value }}</span>
</template>
