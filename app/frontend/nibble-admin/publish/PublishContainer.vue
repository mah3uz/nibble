<script setup lang="ts">
import { computed, ref, watch } from 'vue'
import type { PublishBlueprint } from '../fieldtypes/types'
import { getPath, omitPaths, setPath, withoutKey } from '../lib/paths'
import { provideContainer, type HiddenState } from './context'
import PublishTabs from './PublishTabs.vue'

const props = withDefaults(
  defineProps<{
    blueprint: PublishBlueprint
    name?: string
    meta?: Record<string, unknown>
    errors?: Record<string, string[]>
    extraValues?: Record<string, unknown>
    readOnly?: boolean
  }>(),
  { name: 'base', meta: () => ({}), errors: () => ({}), extraValues: () => ({}), readOnly: false },
)
const model = defineModel<Record<string, unknown>>({ default: () => ({}) })
const emit = defineEmits<{
  'update:meta': [meta: Record<string, unknown>]
  'update:visibleValues': [values: Record<string, unknown>]
}>()

const values = ref<Record<string, unknown>>(model.value)
const meta = ref<Record<string, unknown>>(props.meta)
const hiddenFields = ref<Record<string, HiddenState>>({})

watch(model, (incoming) => incoming !== values.value && (values.value = incoming))
watch(
  () => props.meta,
  (incoming) => (meta.value = incoming),
)

function setFieldValue(path: string, value: unknown) {
  if (getPath(values.value, path) === value) return
  values.value = setPath(values.value, path, value)
  model.value = values.value
}

function setFieldMeta(path: string, value: unknown) {
  meta.value = setPath(meta.value, path, value)
  emit('update:meta', meta.value)
}

// Values the server should receive: fields hidden by conditions are dropped unless they opt into always_save.
const visibleValues = computed(() =>
  omitPaths(
    values.value,
    Object.entries(hiddenFields.value)
      .filter(([, state]) => state.hidden && state.omitValue)
      .map(([path]) => path),
  ),
)
watch(visibleValues, (visible) => emit('update:visibleValues', visible), { immediate: true })

provideContainer({
  name: props.name,
  values,
  meta,
  errors: computed(() => props.errors),
  readOnly: computed(() => props.readOnly),
  extraValues: computed(() => props.extraValues),
  hiddenFields,
  setFieldValue,
  setFieldMeta,
  setHiddenField: (path, state) => (hiddenFields.value = { ...hiddenFields.value, [path]: state }),
  unsetHiddenField: (path) => {
    hiddenFields.value = withoutKey(hiddenFields.value, path)
  },
})

defineExpose({ values, visibleValues, setFieldValue, setFieldMeta })
</script>

<template>
  <slot :values="values" :visible-values="visibleValues">
    <PublishTabs :tabs="blueprint.tabs" />
  </slot>
</template>
