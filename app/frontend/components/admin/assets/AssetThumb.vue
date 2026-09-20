<script setup lang="ts">
import FileIcon from './FileIcon.vue'

defineProps<{ thumbnail: string | null; extension: string; iconClass?: string }>()
</script>

<template>
  <img v-if="thumbnail" :src="thumbnail" loading="lazy" draggable="false" alt="" />
  <FileIcon v-else :extension="extension" :class="iconClass ?? 'size-1/3!'" />
</template>
