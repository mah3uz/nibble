<script setup lang="ts">
import { computed } from 'vue'
import { Checkbox } from '@/components/ui/checkbox'
import { normalizeOptions, optionKey } from '../options'
import { fieldtypeEmits, fieldtypeProps, useFieldtype } from '../useFieldtype'

const props = defineProps(fieldtypeProps)
const emit = defineEmits(fieldtypeEmits)
const { update, isReadOnly, expose } = useFieldtype(emit, props)
defineExpose(expose)

const options = computed(() => normalizeOptions(props.meta, props.config))
const selected = computed(() => ((props.value as unknown[] | null) ?? []).map(optionKey))

function toggle(value: unknown, checked: boolean) {
  const current = ((props.value as unknown[] | null) ?? []).filter((item) => optionKey(item) !== optionKey(value))
  update(
    checked
      ? options.value
          .map((option) => option.value)
          .filter((item) => [...current.map(optionKey), optionKey(value)].includes(optionKey(item)))
      : current,
  )
}
</script>

<template>
  <div :id="id" :class="config.inline ? 'flex flex-wrap gap-x-6 gap-y-2' : 'flex flex-col gap-2'">
    <label
      v-for="option in options"
      :key="optionKey(option.value)"
      class="flex items-center gap-2 text-sm text-gray-800 dark:text-gray-200"
    >
      <Checkbox
        :model-value="selected.includes(optionKey(option.value))"
        :disabled="isReadOnly"
        @update:model-value="(checked) => toggle(option.value, checked === true)"
      />
      {{ option.label }}
    </label>
  </div>
</template>
