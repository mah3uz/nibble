<script setup lang="ts">
import { computed } from 'vue'
import type { PublishField as Field } from '../fieldtypes/types'
import { provideFields, useFieldsContext } from './context'
import PublishField from './PublishField.vue'

const props = defineProps<{ fields: Field[]; fieldPathPrefix?: string; metaPathPrefix?: string; readOnly?: boolean }>()
const parent = useFieldsContext()

const context = computed(() => ({
  fieldPathPrefix: props.fieldPathPrefix,
  metaPathPrefix: props.metaPathPrefix ?? props.fieldPathPrefix,
  readOnly: props.readOnly || parent?.value.readOnly || false,
}))
provideFields(context)
</script>

<template>
  <div class="publish-fields">
    <PublishField
      v-for="field in fields"
      :key="field.handle"
      :field="field"
      :field-path-prefix="context.fieldPathPrefix"
      :meta-path-prefix="context.metaPathPrefix"
      :read-only="context.readOnly"
    />
  </div>
</template>
