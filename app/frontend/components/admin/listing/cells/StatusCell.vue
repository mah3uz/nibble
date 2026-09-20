<script setup lang="ts">
import { capitalize } from '@/lib/format'

defineProps<{ value: string | null }>()
const tone: Record<string, string> = {
  published: 'bg-green-200 text-green-900 dark:bg-green-300/6 dark:text-green-300',
  scheduled: 'bg-amber-200 text-amber-900 dark:bg-amber-300/6 dark:text-amber-300',
  delivered: 'bg-green-200 text-green-900 dark:bg-green-300/6 dark:text-green-300',
  enabled: 'bg-green-200 text-green-900 dark:bg-green-300/6 dark:text-green-300',
  pending: 'bg-amber-200 text-amber-900 dark:bg-amber-300/6 dark:text-amber-300',
  disabled: 'bg-red-200 text-red-900 dark:bg-red-300/6 dark:text-red-300',
  failed: 'bg-red-200 text-red-900 dark:bg-red-300/6 dark:text-red-300',
  rejected: 'bg-red-200 text-red-900 dark:bg-red-300/6 dark:text-red-300',
  healthy: 'bg-green-200 text-green-900 dark:bg-green-300/6 dark:text-green-300',
  warning: 'bg-amber-200 text-amber-900 dark:bg-amber-300/6 dark:text-amber-300',
  degraded: 'bg-amber-200 text-amber-900 dark:bg-amber-300/6 dark:text-amber-300',
  failing: 'bg-red-200 text-red-900 dark:bg-red-300/6 dark:text-red-300',
  down: 'bg-red-200 text-red-900 dark:bg-red-300/6 dark:text-red-300',
}
</script>

<template>
  <span
    v-if="value"
    :class="[
      'inline-block shrink rounded-full px-2 py-0.5 text-center text-xs select-none',
      tone[value] ?? 'bg-gray-200 text-gray-900 dark:bg-gray-300/8 dark:text-gray-300',
    ]"
    >{{ capitalize(value) }}</span
  >
  <span v-else class="text-sm text-muted-foreground">—</span>
</template>
