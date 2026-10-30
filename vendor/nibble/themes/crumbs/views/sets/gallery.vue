<script setup lang="ts">
import { Image } from '@nibble'
import type { AssetValue } from '@site/types'

defineProps<{ images: AssetValue[] | null }>()
</script>

<template>
  <div v-if="images?.length" class="not-prose grid grid-cols-2 gap-4">
    <Image
      v-for="image in images"
      :key="image.url"
      :image="image"
      sizes="(min-width: 768px) 32ch, 50vw"
      class="aspect-square w-full rounded-lg object-cover"
    />
  </div>
</template>
