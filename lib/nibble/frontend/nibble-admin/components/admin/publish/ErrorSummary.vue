<script setup lang="ts">
import { AlertCircle } from '@lucide/vue'
import { computed } from 'vue'
import { Alert, AlertDescription, AlertTitle } from '@/components/ui/alert'
import type { PublishBlueprint } from './context'

const props = defineProps<{ errors: Record<string, string>; blueprint: PublishBlueprint }>()
const emit = defineEmits<{ jump: [tabHandle: string | null, fieldHandle: string] }>()

function labelFor(path: string): string | null {
  const topHandle = path.split('.')[0]
  for (const tab of props.blueprint.tabs) {
    for (const section of tab.sections) {
      const field = section.fields.find((field) => field.handle === topHandle)
      if (field) return field.display ?? null
    }
  }
  return null
}

function tabFor(path: string): string | null {
  const topHandle = path.split('.')[0]
  const tab = props.blueprint.tabs.find((tab) =>
    tab.sections.some((section) => section.fields.some((field) => field.handle === topHandle)),
  )
  return tab?.handle ?? null
}

const entries = computed(() =>
  Object.entries(props.errors)
    .filter(([, message]) => message)
    .map(([path, message]) => {
      const label = labelFor(path)
      return { path, text: label ? `${label} ${message}` : message }
    }),
)
</script>

<template>
  <Alert v-if="entries.length" variant="destructive">
    <AlertCircle />
    <AlertTitle>Please fix the following</AlertTitle>
    <AlertDescription>
      <ul class="list-disc space-y-1 pl-4">
        <li v-for="entry in entries" :key="entry.path">
          <button
            type="button"
            class="text-left underline underline-offset-2"
            @click="emit('jump', tabFor(entry.path), entry.path.split('.')[0])"
          >
            {{ entry.text }}
          </button>
        </li>
      </ul>
    </AlertDescription>
  </Alert>
</template>
