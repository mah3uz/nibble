<script setup lang="ts">
defineProps<{ title: string; description?: string | null }>()
</script>

<template>
  <header class="flex flex-wrap items-start justify-between gap-4 border-b pb-4">
    <div>
      <h1 class="text-2xl font-semibold tracking-tight">{{ title }}</h1>
      <p v-if="description" class="mt-1 text-sm text-muted-foreground">{{ description }}</p>
    </div>
    <div class="flex flex-wrap items-center gap-2"><slot name="actions" /></div>
  </header>
</template>
