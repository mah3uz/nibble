<script setup lang="ts">
defineProps<{ url: string; caption?: string | null }>()
</script>

<template>
  <figure>
    <a :href="url">{{ caption || url }}</a>
  </figure>
</template>
