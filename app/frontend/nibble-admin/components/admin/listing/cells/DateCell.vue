<script setup lang="ts">
const props = defineProps<{ value: string | null }>()
const date = (iso: string | null) => (iso ? new Date(iso).toLocaleDateString('en-AU') : '—')
</script>

<template>
  <span class="text-sm">{{ date(props.value) }}</span>
</template>
