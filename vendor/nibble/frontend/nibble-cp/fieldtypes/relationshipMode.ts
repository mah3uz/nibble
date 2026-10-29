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

export function nextIds(ids: string[], id: string, { single, max }: { single: boolean; max: number }): string[] {
  if (single) return [id]
  if (ids.includes(id) || (max > 0 && ids.length >= max)) return ids
  return [...ids, id]
}

export function chooseLabel(display: unknown, single: boolean): string {
  const noun = typeof display === 'string' ? display.trim().replace(/^[A-Z](?![A-Z])/, (c) => c.toLowerCase()) : ''
  if (!noun) return 'Choose…'
  if (!single) return `Choose ${noun}…`
  return `Choose ${/^[aeiou]/i.test(noun) ? 'an' : 'a'} ${noun}…`
}

export function unplacedErrors(errors: Record<string, string>, placed: string[]): string[] {
  return Object.entries(errors)
    .filter(([key]) => !placed.includes(key))
    .map(([, message]) => message)
}

export function latestRequest() {
  let current = 0
  return () => {
    const mine = ++current
    return () => mine === current
  }
}
