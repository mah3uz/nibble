<script setup lang="ts">
import { computed } from 'vue'
import { Switch } from '@/components/ui/switch'
import { fieldtypeEmits, fieldtypeProps, useFieldtype } from '../useFieldtype'

const props = defineProps(fieldtypeProps)
const emit = defineEmits(fieldtypeEmits)
const { update, isReadOnly, expose } = useFieldtype(emit, props)
defineExpose(expose)

const label = computed(() =>
  props.value && props.config.inline_label_when_true ? props.config.inline_label_when_true : props.config.inline_label,
)
</script>

<template>
  <div class="flex items-center gap-2">
    <Switch :id="id" :model-value="value === true" :disabled="isReadOnly" @update:model-value="update" />
    <!-- eslint-disable vue/no-v-html -->
    <label
      v-if="config.inline_label_html && !(value && config.inline_label_when_true)"
      :for="id"
      class="text-sm text-gray-700 dark:text-gray-300 [&_a]:underline"
      v-html="config.inline_label_html"
    />
    <!-- eslint-enable vue/no-v-html -->
    <label v-else-if="label" :for="id" class="text-sm text-gray-700 dark:text-gray-300">{{ label }}</label>
  </div>
</template>
