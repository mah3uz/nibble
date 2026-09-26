<script setup lang="ts">
import { AlertTriangle, History } from '@lucide/vue'
import { computed } from 'vue'
import { Alert, AlertDescription, AlertTitle } from '@/components/ui/alert'
import { Button } from '@/components/ui/button'
import type { LocalBackup } from '@/lib/local-backup'

const props = defineProps<{ backup: LocalBackup; savedSince: boolean }>()
const emit = defineEmits<{ restore: []; discard: [] }>()

const when = computed(() =>
  new Date(props.backup.savedAt).toLocaleString('en-AU', { dateStyle: 'medium', timeStyle: 'short' }),
)
</script>

<template>
  <Alert :variant="savedSince ? 'destructive' : 'default'">
    <AlertTriangle v-if="savedSince" />
    <History v-else />
    <AlertTitle>Unsaved changes from {{ when }} were kept in this browser.</AlertTitle>
    <AlertDescription>
      <p v-if="savedSince">This page has been saved since then. Restoring puts your older changes back over it.</p>
      <div class="flex items-center gap-2 pt-1">
        <Button type="button" variant="secondary" size="sm" @click="emit('restore')">Restore</Button>
        <Button type="button" variant="outline" size="sm" @click="emit('discard')">Discard</Button>
      </div>
    </AlertDescription>
  </Alert>
</template>
