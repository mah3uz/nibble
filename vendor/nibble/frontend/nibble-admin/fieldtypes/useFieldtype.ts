import { useDebounceFn } from '@vueuse/core'
import { computed, ref, watch, type PropType } from 'vue'
import { fieldActions as resolveActions, type FieldActionDefinition } from './actions'
import type { FieldConfig } from './types'

export const UPDATE_DEBOUNCE_MS = 150

export const fieldtypeProps = {
  value: { required: true as const },
  config: { type: Object as PropType<FieldConfig>, default: () => ({}) },
  handle: { type: String, required: true as const },
  meta: { type: Object as PropType<Record<string, unknown>>, default: () => ({}) },
  readOnly: { type: Boolean, default: false },
  showFieldPreviews: { type: Boolean, default: false },
  namePrefix: String,
  fieldPathPrefix: String,
  metaPathPrefix: String,
  id: String,
}

export type FieldtypeEvent = 'update:value' | 'update:meta' | 'focus' | 'blur' | 'replicator-preview-updated'
export const fieldtypeEmits: FieldtypeEvent[] = [
  'update:value',
  'update:meta',
  'focus',
  'blur',
  'replicator-preview-updated',
]

export type FieldtypeProps = {
  value: unknown
  config: FieldConfig
  handle: string
  meta: Record<string, unknown>
  readOnly: boolean
  showFieldPreviews: boolean
  namePrefix?: string
  fieldPathPrefix?: string
  metaPathPrefix?: string
  id?: string
}

type Emit = (event: FieldtypeEvent, ...args: unknown[]) => void

export function useFieldtype(emit: Emit, props: FieldtypeProps) {
  const name = computed(() => (props.namePrefix ? `${props.namePrefix}[${props.handle}]` : props.handle))
  const isReadOnly = computed(
    () => props.readOnly || props.config.visibility === 'read_only' || props.config.visibility === 'computed',
  )

  const previewDefinition = ref<(() => unknown) | null>(null)
  const replicatorPreview = computed(() => {
    if (!props.showFieldPreviews) return undefined
    return previewDefinition.value ? previewDefinition.value() : props.value
  })
  const defineReplicatorPreview = (definition: () => unknown) => (previewDefinition.value = definition)
  watch(replicatorPreview, (preview) => props.showFieldPreviews && emit('replicator-preview-updated', preview), {
    immediate: true,
  })

  const fieldPathKeys = computed(() => (props.fieldPathPrefix || props.handle).split('.'))

  const update = (value: unknown) => emit('update:value', value)
  const updateDebounced = useDebounceFn(update, UPDATE_DEBOUNCE_MS)
  const updateMeta = (meta: unknown) => emit('update:meta', meta)

  const internalActions = ref<FieldActionDefinition[]>([])
  const defineFieldActions = (actions: FieldActionDefinition[]) => (internalActions.value = actions)
  const fieldActions = computed(() =>
    resolveActions(
      `${props.config.type}-fieldtype`,
      {
        fieldPathPrefix: props.fieldPathPrefix,
        handle: props.handle,
        value: props.value,
        config: props.config,
        meta: props.meta,
        update,
        updateMeta,
        isReadOnly: isReadOnly.value,
      },
      internalActions.value,
    ),
  )

  return {
    name,
    isReadOnly,
    replicatorPreview,
    defineReplicatorPreview,
    fieldPathKeys,
    defineFieldActions,
    fieldActions,
    update,
    updateDebounced,
    updateMeta,
    expose: { handle: props.handle, name, fieldActions, replicatorPreview },
  }
}
