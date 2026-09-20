<script setup lang="ts">
defineProps<{ source: string }>()
</script>

<template>
  <div class="font-mono text-[13px] leading-relaxed whitespace-pre-wrap text-gray-700 dark:text-gray-300">
    {{ source }}
  </div>
</template>
