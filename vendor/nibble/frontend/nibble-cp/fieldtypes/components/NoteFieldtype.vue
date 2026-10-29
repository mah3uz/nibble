<script setup lang="ts">
import { fieldtypeEmits, fieldtypeProps, useFieldtype } from '../useFieldtype'

const emit = defineEmits(fieldtypeEmits)
const props = defineProps(fieldtypeProps)
const { expose } = useFieldtype(emit, props)
defineExpose(expose)
</script>

<template>
  <!-- eslint-disable vue/no-v-html -->
  <div
    class="text-sm text-muted-foreground [&_a]:underline [&_ol]:list-decimal [&_ol]:pl-5 [&_p+p]:mt-2 [&_ul]:list-disc [&_ul]:pl-5"
    v-html="config.text_html"
  />
  <!-- eslint-enable vue/no-v-html -->
</template>
