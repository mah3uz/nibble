<script setup lang="ts">
import { computed } from 'vue'
import type { ImageValue } from './types'

const props = withDefaults(
  defineProps<{ image: ImageValue | null | undefined; sizes?: string; loading?: 'lazy' | 'eager' }>(),
  {
    sizes: '100vw',
    loading: 'lazy',
  },
)

const position = computed(() =>
  props.image?.focal ? `${props.image.focal.x * 100}% ${props.image.focal.y * 100}%` : undefined,
)
</script>

<template>
  <img
    v-if="image"
    :src="image.url"
    :srcset="image.srcset ?? undefined"
    :sizes="image.srcset ? sizes : undefined"
    :alt="image.alt ?? ''"
    :width="image.width ?? undefined"
    :height="image.height ?? undefined"
    :loading="loading"
    :style="position ? { objectPosition: position } : undefined"
  />
</template>
