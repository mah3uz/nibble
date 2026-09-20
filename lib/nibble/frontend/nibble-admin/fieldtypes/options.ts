export type Option = { value: unknown; label: string }

export function normalizeOptions(meta: Record<string, unknown>, config: Record<string, unknown>): Option[] {
  if (Array.isArray(meta.options)) return meta.options as Option[]
  const raw = config.options
  if (Array.isArray(raw)) {
    return raw.map((item) =>
      item !== null && typeof item === 'object'
        ? {
            value: (item as Record<string, unknown>).key ?? (item as Record<string, unknown>).value,
            label: String((item as Record<string, unknown>).label ?? (item as Record<string, unknown>).value),
          }
        : { value: item, label: String(item) },
    )
  }
  if (raw && typeof raw === 'object')
    return Object.entries(raw).map(([value, label]) => ({ value, label: String(label ?? value) }))
  return []
}

export const optionKey = (value: unknown) => JSON.stringify(value)
