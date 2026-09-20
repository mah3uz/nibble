<script setup lang="ts">
import { usePage } from '@inertiajs/vue3'
import { computed } from 'vue'

const page = usePage<{ preview?: { label: string; edit_url?: string } | null }>()
const preview = computed(() => page.props.preview)
</script>

<template>
  <div v-if="preview" role="status" data-nibble-preview>
    <slot :preview="preview">
      {{ preview.label }}
      <a v-if="preview.edit_url" :href="preview.edit_url">Edit</a>
    </slot>
  </div>
</template>
