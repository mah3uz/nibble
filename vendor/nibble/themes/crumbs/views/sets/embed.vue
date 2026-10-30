<script setup lang="ts">
import { computed } from 'vue'
import { embedSrc, isLinkable } from '../../lib/embed'

const props = defineProps<{ url: string; caption?: string | null }>()

const src = computed(() => embedSrc(props.url))
</script>

<template>
  <figure>
    <iframe
      v-if="src"
      :src="src"
      :title="caption || 'Embedded video'"
      loading="lazy"
      referrerpolicy="strict-origin-when-cross-origin"
      sandbox="allow-scripts allow-same-origin allow-presentation allow-popups"
      allow="fullscreen; picture-in-picture"
      allowfullscreen
      class="aspect-video w-full rounded-lg"
    ></iframe>
    <a v-else-if="isLinkable(url)" :href="url" rel="noopener noreferrer">{{ caption || url }}</a>
    <figcaption v-if="src && caption">{{ caption }}</figcaption>
  </figure>
</template>
