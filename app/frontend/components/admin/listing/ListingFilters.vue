<script setup lang="ts">
import { SlidersHorizontal } from '@lucide/vue'
import { computed } from 'vue'
import { Button } from '@/components/ui/button'
import { Checkbox } from '@/components/ui/checkbox'
import { Label } from '@/components/ui/label'
import { Popover, PopoverContent, PopoverTrigger } from '@/components/ui/popover'
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select'
import type { ListingFilter } from './types'

const props = defineProps<{ filters: ListingFilter[] }>()
const emit = defineEmits<{ change: [handle: string, value: string | string[] | null] }>()

const ALL = '__all__'

const activeCount = computed(
  () => props.filters.filter((f) => (Array.isArray(f.value) ? f.value.length > 0 : !!f.value)).length,
)

function toggleMulti(filter: ListingFilter, value: string, checked: boolean) {
  const current = Array.isArray(filter.value) ? filter.value : []
  emit('change', filter.handle, checked ? [...current, value] : current.filter((v) => v !== value))
}
</script>

<template>
  <Popover v-if="filters.length">
    <PopoverTrigger as-child>
      <Button variant="outline">
        <SlidersHorizontal />
        Filters
        <span
          v-if="activeCount"
          class="-me-1 inline-flex size-5 items-center justify-center rounded-full bg-ui-accent-bg text-xs text-white"
          >{{ activeCount }}</span
        >
      </Button>
    </PopoverTrigger>
    <PopoverContent align="start" class="w-80 space-y-5 p-4">
      <div v-for="filter in filters" :key="filter.handle" class="flex flex-col gap-2">
        <Label :for="`filter-${filter.handle}`">{{ filter.label }}</Label>
        <Select
          v-if="filter.type !== 'multi_select'"
          :model-value="(filter.value as string) || ALL"
          @update:model-value="(v) => emit('change', filter.handle, v === ALL ? null : String(v))"
        >
          <SelectTrigger :id="`filter-${filter.handle}`" :aria-label="filter.label"><SelectValue /></SelectTrigger>
          <SelectContent>
            <SelectItem :value="ALL">All</SelectItem>
            <SelectItem v-for="option in filter.options" :key="option.value" :value="option.value">{{
              option.label
            }}</SelectItem>
          </SelectContent>
        </Select>
        <div v-else :id="`filter-${filter.handle}`" class="max-h-48 space-y-2 overflow-y-auto">
          <div v-for="option in filter.options" :key="option.value" class="relative flex items-start gap-2">
            <Checkbox
              :id="`filter-${filter.handle}-${option.value}`"
              class="mt-0.5"
              :model-value="Array.isArray(filter.value) && filter.value.includes(option.value)"
              @update:model-value="(checked) => toggleMulti(filter, option.value, !!checked)"
            />
            <label :for="`filter-${filter.handle}-${option.value}`" class="cursor-pointer text-sm antialiased">{{
              option.label
            }}</label>
          </div>
        </div>
      </div>
    </PopoverContent>
  </Popover>
</template>
