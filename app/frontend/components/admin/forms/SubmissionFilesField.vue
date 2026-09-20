<script setup lang="ts">
import { computed } from 'vue'
import { fieldtypeEmits, fieldtypeProps, useFieldtype } from '@/nibble-admin/fieldtypes/useFieldtype'

type FileLink = { filename: string; size: number; url: string }

const props = defineProps(fieldtypeProps)
const emit = defineEmits(fieldtypeEmits)
const { expose } = useFieldtype(emit, props)
defineExpose(expose)

const files = computed(() => ((props.meta as { files?: FileLink[] } | null)?.files ?? []) as FileLink[])
const size = (bytes: number) =>
  bytes < 1024
    ? `${bytes} B`
    : bytes < 1048576
      ? `${(bytes / 1024).toFixed(1)} KB`
      : `${(bytes / 1048576).toFixed(1)} MB`
</script>

<template>
  <div class="rounded-lg border border-dashed border-gray-300 px-3 py-2.5 text-sm dark:border-gray-700">
    <ul v-if="files.length" class="space-y-1">
      <li v-for="file in files" :key="file.url" class="flex items-center justify-between gap-3">
        <a :href="file.url" class="truncate text-blue-700 hover:underline dark:text-blue-400">{{ file.filename }}</a>
        <span class="shrink-0 text-gray-500">{{ size(file.size) }}</span>
      </li>
    </ul>
    <span v-else class="text-gray-500">No files</span>
  </div>
</template>
