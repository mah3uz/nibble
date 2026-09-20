export type FieldActionPayload = {
  fieldPathPrefix: string | undefined
  handle: string
  value: unknown
  config: Record<string, unknown>
  meta: Record<string, unknown>
  update: (value: unknown) => void
  updateMeta: (meta: unknown) => void
  isReadOnly: boolean
}

type Dynamic<T> = T | ((payload: FieldActionPayload) => T)

export type FieldActionDefinition = {
  title: string
  run: (payload: FieldActionPayload) => unknown
  icon?: Dynamic<string>
  visible?: Dynamic<boolean>
  visibleWhenReadOnly?: boolean
  disabled?: Dynamic<boolean>
  quick?: Dynamic<boolean>
  dangerous?: Dynamic<boolean>
}

export type FieldAction = {
  title: string
  icon: string
  disabled: boolean
  quick: boolean
  dangerous: boolean
  run: () => unknown
}

const registry = new Map<string, FieldActionDefinition[]>()

// `binding` is `<fieldtype handle>-fieldtype`, so extensions can add actions to any fieldtype.
export function registerFieldAction(binding: string, action: FieldActionDefinition) {
  registry.set(binding, [...(registry.get(binding) ?? []), action])
}

export function clearFieldActions(binding?: string) {
  if (binding) registry.delete(binding)
  else registry.clear()
}

const resolve = <T>(value: Dynamic<T> | undefined, payload: FieldActionPayload, fallback: T): T =>
  value === undefined
    ? fallback
    : typeof value === 'function'
      ? (value as (p: FieldActionPayload) => T)(payload)
      : value

export function fieldActions(
  binding: string,
  payload: FieldActionPayload,
  internal: FieldActionDefinition[] = [],
): FieldAction[] {
  return [...(registry.get(binding) ?? []), ...internal]
    .filter((action) =>
      payload.isReadOnly && !action.visibleWhenReadOnly ? false : resolve(action.visible, payload, true),
    )
    .map((action) => ({
      title: action.title,
      icon: resolve(action.icon, payload, 'image'),
      disabled: resolve(action.disabled, payload, false),
      quick: resolve(action.quick, payload, false),
      dangerous: resolve(action.dangerous, payload, false),
      run: () => action.run(payload),
    }))
}
