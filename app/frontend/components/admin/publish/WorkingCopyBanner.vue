<script setup lang="ts">
import { useTimeAgo } from '@vueuse/core'
import { AlertTriangle, History } from '@lucide/vue'
import { Alert, AlertDescription, AlertTitle } from '@/components/ui/alert'
import { Button } from '@/components/ui/button'
import type { DraftMeta } from './context'

const props = defineProps<{ workingCopy: NonNullable<DraftMeta>; processing: boolean }>()
const emit = defineEmits<{ preview: []; discard: []; publish: []; 'view-history': [] }>()

const timeAgo = useTimeAgo(() => props.workingCopy.updated_at)
</script>

<template>
  <Alert :variant="workingCopy.stale ? 'destructive' : 'default'">
    <AlertTriangle v-if="workingCopy.stale" />
    <History v-else />
    <AlertTitle v-if="workingCopy.stale">The live version changed after these changes were started.</AlertTitle>
    <AlertTitle v-else>
      Unpublished changes{{ workingCopy.user ? ` by ${workingCopy.user}` : '' }}, {{ timeAgo }}.
    </AlertTitle>
    <AlertDescription>
      <div class="flex items-center gap-2 pt-1">
        <Button v-if="workingCopy.stale" type="button" variant="outline" size="sm" @click="emit('view-history')"
          >View history</Button
        >
        <template v-else>
          <Button type="button" variant="outline" size="sm" @click="emit('preview')">Preview</Button>
          <Button type="button" variant="outline" size="sm" :disabled="processing" @click="emit('discard')"
            >Discard</Button
          >
          <Button type="button" variant="secondary" size="sm" :disabled="processing" @click="emit('publish')"
            >Publish changes</Button
          >
        </template>
      </div>
    </AlertDescription>
  </Alert>
</template>
