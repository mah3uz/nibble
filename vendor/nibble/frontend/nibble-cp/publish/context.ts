import { inject, provide, type ComputedRef, type InjectionKey, type Ref } from 'vue'

export type HiddenState = { hidden: boolean; omitValue: boolean }

export type ContainerContext = {
  name: string
  values: Ref<Record<string, unknown>>
  meta: Ref<Record<string, unknown>>
  errors: ComputedRef<Record<string, string[]>>
  readOnly: ComputedRef<boolean>
  extraValues: ComputedRef<Record<string, unknown>>
  hiddenFields: Ref<Record<string, HiddenState>>
  setFieldValue: (path: string, value: unknown) => void
  setFieldMeta: (path: string, meta: unknown) => void
  setHiddenField: (path: string, state: HiddenState) => void
  unsetHiddenField: (path: string) => void
}

const CONTAINER: InjectionKey<ContainerContext> = Symbol('nibble-publish-container')

export function provideContainer(context: ContainerContext) {
  provide(CONTAINER, context)
}

export function useContainer() {
  const context = inject(CONTAINER, null)
  if (!context) throw new Error('Publish components must be rendered inside a PublishContainer')
  return context
}

export type FieldsContext = {
  fieldPathPrefix: string | undefined
  metaPathPrefix: string | undefined
  readOnly: boolean
}

const FIELDS: InjectionKey<ComputedRef<FieldsContext>> = Symbol('nibble-publish-fields')

export function provideFields(context: ComputedRef<FieldsContext>) {
  provide(FIELDS, context)
}

export function useFieldsContext() {
  return inject(FIELDS, null)
}
