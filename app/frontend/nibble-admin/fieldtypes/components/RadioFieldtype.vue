<script setup lang="ts">
import { RadioGroupIndicator, RadioGroupItem, RadioGroupRoot } from 'reka-ui'
import { computed } from 'vue'
import { normalizeOptions, optionKey } from '../options'
import { fieldtypeEmits, fieldtypeProps, useFieldtype } from '../useFieldtype'

const props = defineProps(fieldtypeProps)
const emit = defineEmits(fieldtypeEmits)
const { update, isReadOnly, expose } = useFieldtype(emit, props)
defineExpose(expose)

const options = computed(() => normalizeOptions(props.meta, props.config))
const selectedKey = computed(() => (props.value == null ? undefined : optionKey(props.value)))

function select(key: unknown) {
  update(options.value.find((option) => optionKey(option.value) === key)?.value ?? null)
}
</script>

<template>
  <RadioGroupRoot
    :id="id"
    :model-value="selectedKey"
    :disabled="isReadOnly"
    :class="config.inline ? 'flex flex-wrap gap-x-6 gap-y-2' : 'flex flex-col gap-2'"
    @update:model-value="select"
  >
    <label
      v-for="option in options"
      :key="optionKey(option.value)"
      class="flex items-center gap-2 text-sm text-gray-800 dark:text-gray-200"
    >
      <RadioGroupItem
        :value="optionKey(option.value)"
        class="relative flex size-4 shrink-0 items-center justify-center rounded-full border border-gray-400/75 bg-white shadow-ui-xs outline-none focus-visible:focus-outline disabled:cursor-not-allowed disabled:opacity-50 data-[state=checked]:border-ui-accent-bg dark:border-none dark:bg-gray-500"
      >
        <RadioGroupIndicator class="size-2 rounded-full bg-ui-accent-bg" />
      </RadioGroupItem>
      {{ option.label }}
    </label>
  </RadioGroupRoot>
</template>
