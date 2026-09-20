<script setup lang="ts">
import { computed, onBeforeUnmount, ref, watch } from 'vue'
import AdminIcon from '@/components/admin/icons/AdminIcon.vue'
import { Button } from '@/components/ui/button'
import { FieldDescription, FieldError } from '@/components/ui/field'
import { Label } from '@/components/ui/label'
import { isVisible } from '../conditions'
import type { FieldAction } from '../fieldtypes/actions'
import { resolveFieldtype } from '../fieldtypes/registry'
import { fieldConfig, type PublishField } from '../fieldtypes/types'
import { getPath, joinPath } from '../lib/paths'
import { useContainer } from './context'

const props = defineProps<{
  field: PublishField
  fieldPathPrefix?: string
  metaPathPrefix?: string
  readOnly?: boolean
}>()
const container = useContainer()

const path = computed(() => joinPath(props.fieldPathPrefix, props.field.handle))
const metaPath = computed(() => joinPath(props.metaPathPrefix ?? props.fieldPathPrefix, props.field.handle))
const value = computed(() => getPath(container.values.value, path.value))
const meta = computed(() => (getPath(container.meta.value, metaPath.value) ?? {}) as Record<string, unknown>)
const config = computed(() => fieldConfig(props.field))
const component = computed(() => resolveFieldtype(props.field.component))

const siblings = computed(
  () =>
    ({
      ...container.extraValues.value,
      ...((props.fieldPathPrefix
        ? getPath(container.values.value, props.fieldPathPrefix)
        : container.values.value) as Record<string, unknown>),
    }) as Record<string, unknown>,
)
const visible = computed(() =>
  isVisible(props.field, {
    values: siblings.value,
    rootValues: container.values.value,
    path: path.value,
    prefix: props.field.prefix,
  }),
)
watch(
  visible,
  (shown) => {
    if (shown) container.unsetHiddenField(path.value)
    else container.setHiddenField(path.value, { hidden: true, omitValue: !props.field.always_save })
  },
  { immediate: true },
)
onBeforeUnmount(() => container.unsetHiddenField(path.value))

const errors = computed(() => container.errors.value[path.value] ?? [])
const readOnly = computed(() => props.readOnly || container.readOnly.value || props.field.read_only)

const control = ref<{ fieldActions?: FieldAction[] }>()
const actions = computed(() => (props.field.actions ? (control.value?.fieldActions ?? []) : []))
</script>

<template>
  <div
    v-if="visible && field.visibility !== 'hidden'"
    :class="['form-group flex min-w-0 flex-col gap-2', `field-w-${field.width}`]"
    :data-field-path="path"
    :data-invalid="errors.length > 0 || undefined"
  >
    <div v-if="!field.hide_display || actions.length" class="flex flex-col gap-1.5">
      <div class="flex items-center justify-between gap-2">
        <Label v-if="!field.hide_display" :for="path" class="block"
          >{{ field.display }}<span v-if="field.required" class="relative -top-px ms-0.5 text-red-600">*</span></Label
        >
        <div v-if="actions.length" class="flex items-center gap-1">
          <Button
            v-for="action in actions"
            :key="action.title"
            type="button"
            variant="outline"
            class="-my-1 h-7 rounded-md px-2"
            :aria-label="action.title"
            :title="action.title"
            :disabled="action.disabled"
            @click="action.run()"
          >
            <AdminIcon :name="action.icon" class="size-3.5" />
          </Button>
        </div>
      </div>
      <FieldDescription
        v-if="field.instructions && field.instructions_position === 'above'"
        class="st-text-trim-start"
        >{{ field.instructions }}</FieldDescription
      >
    </div>
    <component
      :is="component"
      v-if="component"
      :id="path"
      ref="control"
      :value="value"
      :config="config"
      :handle="field.handle"
      :meta="meta"
      :read-only="readOnly"
      :field-path-prefix="path"
      :meta-path-prefix="metaPath"
      @update:value="(updated: unknown) => container.setFieldValue(path, updated)"
      @update:meta="(updated: unknown) => container.setFieldMeta(metaPath, updated)"
    />
    <p v-else class="text-sm text-red-600">Unsupported fieldtype component "{{ field.component }}"</p>
    <FieldDescription v-if="field.instructions && field.instructions_position === 'below'">{{
      field.instructions
    }}</FieldDescription>
    <FieldError v-if="errors.length" :errors="errors" />
  </div>
</template>
