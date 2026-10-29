export type RelationshipMode = 'auto' | 'default' | 'select' | 'typeahead' | 'stack'
export type Picker = 'loading' | 'select' | 'search' | 'typeahead' | 'stack'

export const AUTO_MAX = 25
export const SELECT_MAX = 50

export function normalizeMode(value: unknown): RelationshipMode {
  return ['default', 'select', 'typeahead', 'stack'].includes(value as string) ? (value as RelationshipMode) : 'auto'
}

export function probeLimit(mode: RelationshipMode): number {
  if (mode === 'auto') return AUTO_MAX + 1
  return mode === 'select' ? SELECT_MAX : 0
}

export function pickerFor(mode: RelationshipMode, loaded: number | null): Picker {
  if (mode === 'typeahead' || mode === 'stack') return mode
  if (mode === 'default') return 'search'
  if (loaded === null) return 'loading'
  return loaded < probeLimit(mode) ? 'select' : 'search'
}
