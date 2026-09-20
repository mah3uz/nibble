<script setup lang="ts">
import { Search } from '@lucide/vue'
import { Input } from '@/components/ui/input'

defineProps<{ placeholder: string }>()
const model = defineModel<string>({ required: true })
</script>

<template>
  <div class="relative w-full sm:w-96">
    <Search class="pointer-events-none absolute top-1/2 left-3 size-4 -translate-y-1/2 text-gray-400" />
    <Input v-model="model" :placeholder="placeholder" class="ps-9" aria-label="Search" />
  </div>
</template>
