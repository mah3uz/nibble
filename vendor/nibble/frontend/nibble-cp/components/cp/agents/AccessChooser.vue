<script setup lang="ts">
import { computed } from 'vue'
import { Checkbox } from '@/components/ui/checkbox'

export type Preset = { value: string; label: string; description: string; available: boolean }
export type Area = {
  key: string
  title: string
  group: string
  columns: { value: string; label: string; available: boolean }[]
}

const props = defineProps<{ presets: Preset[]; areas: Area[] }>()
const preset = defineModel<string>('preset', { required: true })
const selection = defineModel<Record<string, string[]>>('selection', { required: true })

const choosable = computed(() => props.areas.filter((area) => area.columns.some((column) => column.available)))

function toggle(area: string, column: string, on: boolean) {
  const current = selection.value[area] ?? []
  selection.value = {
    ...selection.value,
    [area]: on ? [...current, column] : current.filter((item) => item !== column),
  }
}
</script>

<template>
  <fieldset class="space-y-2">
    <legend class="sr-only">What the app may do</legend>
    <label
      v-for="option in presets"
      :key="option.value"
      class="flex gap-3 rounded-lg border p-3 text-sm has-checked:border-gray-900 has-disabled:opacity-50 dark:has-checked:border-white"
    >
      <input
        v-model="preset"
        type="radio"
        name="preset"
        :value="option.value"
        :disabled="!option.available"
        class="mt-0.5 accent-gray-900 dark:accent-white"
      />
      <span>
        <span class="block font-medium">{{ option.label }}</span>
        <span class="block text-muted-foreground">{{ option.description }}</span>
      </span>
    </label>
  </fieldset>

  <div v-if="preset === 'custom'" class="mt-3 max-h-72 space-y-3 overflow-y-auto rounded-lg border p-3">
    <p v-if="!choosable.length" class="text-sm text-muted-foreground">Nothing is available to choose.</p>
    <div v-for="area in choosable" :key="area.key">
      <p class="text-sm font-medium">
        {{ area.title }} <span class="text-xs font-normal text-muted-foreground">{{ area.group }}</span>
      </p>
      <div class="mt-1 flex flex-wrap gap-x-4 gap-y-1">
        <label
          v-for="column in area.columns.filter((item) => item.available)"
          :key="column.value"
          class="flex items-center gap-1.5 text-sm"
        >
          <Checkbox
            :model-value="(selection[area.key] ?? []).includes(column.value)"
            @update:model-value="(on) => toggle(area.key, column.value, !!on)"
          />
          {{ column.label }}
        </label>
      </div>
    </div>
  </div>
</template>
