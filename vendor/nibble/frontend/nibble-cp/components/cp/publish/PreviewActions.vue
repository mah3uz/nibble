<script setup lang="ts">
import ExternalLinkIcon from '@/components/cp/icons/ExternalLinkIcon.vue'
import LivePreviewIcon from '@/components/cp/icons/LivePreviewIcon.vue'
import { Button } from '@/components/ui/button'

defineProps<{ canPreview: boolean; visitUrl: string | null; poppedOut?: boolean }>()
const emit = defineEmits<{ 'live-preview': []; 'pop-in': [] }>()
</script>

<template>
  <div v-if="canPreview || visitUrl" class="flex flex-wrap gap-3 lg:gap-4">
    <Button
      v-if="canPreview"
      type="button"
      variant="outline"
      class="flex-1"
      @click="poppedOut ? emit('pop-in') : emit('live-preview')"
    >
      <LivePreviewIcon /> {{ poppedOut ? 'Pop in' : 'Live Preview' }}
    </Button>
    <Button v-if="visitUrl" variant="outline" class="flex-1" as-child>
      <a :href="visitUrl" target="_blank" rel="noopener"><ExternalLinkIcon /> Visit URL</a>
    </Button>
  </div>
</template>
