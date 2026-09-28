<script setup lang="ts">
import type { PublishSection as Section } from '../fieldtypes/types'
import PublishSection from './PublishSection.vue'

defineProps<{ sections: Section[] }>()
</script>

<template>
  <PublishSection v-for="(section, index) in sections" :key="index" :section="section" />
</template>
