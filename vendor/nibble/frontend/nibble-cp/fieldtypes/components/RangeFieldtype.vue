<script setup lang="ts">
import { computed } from 'vue'
import { Slider } from '@/components/ui/slider'
import { fieldtypeEmits, fieldtypeProps, useFieldtype } from '../useFieldtype'

const props = defineProps(fieldtypeProps)
const emit = defineEmits(fieldtypeEmits)
const { update, isReadOnly, expose } = useFieldtype(emit, props)
defineExpose(expose)

const min = computed(() => (props.config.min as number | undefined) ?? 0)
const max = computed(() => (props.config.max as number | undefined) ?? 100)
const step = computed(() => (props.config.step as number | undefined) || 1)
const current = computed(() => (typeof props.value === 'number' ? props.value : min.value))

function onUpdate(next: number[] | undefined) {
  if (next?.[0] !== undefined) update(next[0])
}
</script>

<template>
  <div class="flex items-center gap-3">
    <Slider
      :id="id"
      :name="handle"
      :model-value="[current]"
      :min="min"
      :max="max"
      :step="step"
      :disabled="isReadOnly"
      :thumb-label="handle"
      :class="{ 'opacity-60': value == null }"
      @update:model-value="onUpdate"
    />
    <output :for="id" class="min-w-12 text-right text-sm text-gray-700 tabular-nums dark:text-gray-300">
      {{ config.prepend }}{{ current }}{{ config.append }}
    </output>
  </div>
</template>
