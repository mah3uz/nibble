<script setup lang="ts">
import { computed, ref } from 'vue'
import { NativeSelect, NativeSelectOption } from '@/components/ui/native-select'
import type { ItemSummary } from '../../lib/relationships'

const props = defineProps<{ options: ItemSummary[]; selectedIds: string[]; label: string; id?: string }>()
const emit = defineEmits<{ pick: [item: ItemSummary] }>()

const chosen = ref('')
const remaining = computed(() => props.options.filter((item) => !props.selectedIds.includes(item.id)))

function choose(value: unknown) {
  const item = props.options.find((option) => option.id === value)
  chosen.value = ''
  if (item) emit('pick', item)
}
</script>

<template>
  <NativeSelect :id="id" :model-value="chosen" class="w-full" :aria-label="label" @update:model-value="choose">
    <NativeSelectOption value="">{{ label }}</NativeSelectOption>
    <NativeSelectOption v-for="item in remaining" :key="item.id" :value="item.id">{{ item.title }}</NativeSelectOption>
  </NativeSelect>
</template>
