<script lang="ts">
export type Device = 'responsive' | 'laptop' | 'tablet' | 'mobile'
export const DEVICE_SIZES: Record<Exclude<Device, 'responsive'>, { width: number; height: number | null }> = {
  laptop: { width: 1440, height: 900 },
  tablet: { width: 1024, height: null },
  mobile: { width: 375, height: 812 },
}
</script>

<script setup lang="ts">
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select'

const model = defineModel<Device>({ required: true })
const OPTIONS: { value: Device; label: string }[] = [
  { value: 'responsive', label: 'Responsive' },
  { value: 'laptop', label: 'Laptop' },
  { value: 'tablet', label: 'Tablet' },
  { value: 'mobile', label: 'Mobile' },
]
</script>

<template>
  <Select v-model="model">
    <SelectTrigger size="sm" class="w-32">
      <SelectValue />
    </SelectTrigger>
    <SelectContent>
      <SelectItem v-for="option in OPTIONS" :key="option.value" :value="option.value">{{ option.label }}</SelectItem>
    </SelectContent>
  </Select>
</template>
