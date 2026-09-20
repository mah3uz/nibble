<script setup lang="ts">
defineProps<{ value: string[] | null }>()
</script>

<template>
  <span class="text-sm text-muted-foreground">{{ value?.join(', ') || '—' }}</span>
</template>
