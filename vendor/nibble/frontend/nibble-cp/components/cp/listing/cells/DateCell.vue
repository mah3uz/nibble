<script setup lang="ts">
import { formatLocale } from '@/lib/format'
const props = defineProps<{ value: string | null }>()
const date = (iso: string | null) => (iso ? new Date(iso).toLocaleDateString(formatLocale()) : '—')
</script>

<template>
  <span class="text-sm">{{ date(props.value) }}</span>
</template>
