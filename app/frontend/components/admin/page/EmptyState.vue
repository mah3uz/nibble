<script setup lang="ts">
import type { Component } from 'vue'

defineProps<{ icon: Component; title: string; description?: string }>()
</script>

<template>
  <div class="flex flex-col items-center justify-center gap-3 py-16 text-center">
    <component :is="icon" class="size-10 text-muted-foreground" />
    <div class="space-y-1">
      <p class="font-medium">{{ title }}</p>
      <p v-if="description" class="text-sm text-muted-foreground">{{ description }}</p>
    </div>
    <slot />
  </div>
</template>
