<script setup lang="ts">
import { RichText, type RichTextValue } from '@nibble'

defineProps<{ text: RichTextValue }>()
</script>

<template>
  <RichText :value="text" />
</template>
