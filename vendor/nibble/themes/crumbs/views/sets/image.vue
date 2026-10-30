<script setup lang="ts">
import { Image } from '@nibble'
import type { AssetValue } from '@site/types'

defineProps<{ image: AssetValue | null; caption?: string | null }>()
</script>

<template>
  <figure v-if="image">
    <Image :image="image" sizes="(min-width: 768px) 65ch, 100vw" />
    <figcaption v-if="caption">{{ caption }}</figcaption>
  </figure>
</template>
