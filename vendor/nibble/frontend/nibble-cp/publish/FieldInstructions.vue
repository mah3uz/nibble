<script setup lang="ts">
import { computed } from 'vue'
import { instructionParts } from '../lib/instructions'

const props = defineProps<{ text: string }>()
const parts = computed(() => instructionParts(props.text))
</script>

<template>
  <template v-for="(part, index) in parts" :key="index">
    <a
      v-if="part.href"
      :href="part.href"
      target="_blank"
      rel="noopener noreferrer"
      class="underline underline-offset-2 hover:text-foreground"
      >{{ part.text }}</a
    ><template v-else>{{ part.text }}</template>
  </template>
</template>
