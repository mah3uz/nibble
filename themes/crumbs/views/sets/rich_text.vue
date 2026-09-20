<script setup lang="ts">
import { type RichTextValue } from '@nibble'
import Prose from '../../components/Prose.vue'

defineProps<{ text: RichTextValue }>()
</script>

<template>
  <Prose :value="text" />
</template>
