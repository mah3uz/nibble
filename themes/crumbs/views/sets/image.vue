<script setup lang="ts">
import { Image, type ImageValue } from '@nibble'

defineProps<{ image: ImageValue | null; caption?: string | null }>()
</script>

<template>
  <figure v-if="image">
    <Image :image="image" sizes="(min-width: 768px) 65ch, 100vw" />
    <figcaption v-if="caption">{{ caption }}</figcaption>
  </figure>
</template>
