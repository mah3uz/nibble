import { normalizeOptions, optionKey } from './options'
import type { PublishField, PublishSet, PublishSetGroup } from './types'

export type SetRow = { type: string; enabled?: boolean }

export function hasRoom(set: PublishSet, rows: SetRow[]) {
  return !set.max || rows.filter((row) => row.type === set.handle).length < set.max
}

export function addableGroups(groups: PublishSetGroup[], rows: SetRow[]) {
  return groups
    .map((group) => ({ ...group, sets: group.sets.filter((set) => hasRoom(set, rows)) }))
    .filter((group) => group.sets.length > 0)
}

export function activeCount(rows: SetRow[] | null | undefined) {
  return (rows ?? []).filter((row) => row.enabled !== false).length
}

const CHOICES = ['select', 'radio']

export function setPreview(fields: PublishField[], row: Record<string, unknown>, limit = 60) {
  const text = fields
    .filter((field) => field.replicator_preview)
    .flatMap((field) => {
      const value = row[field.handle]
      if (CHOICES.includes(field.type)) {
        const option = normalizeOptions({}, field.config).find((choice) => optionKey(choice.value) === optionKey(value))
        return option ? [option.label] : []
      }
      return typeof value === 'string' && value !== '' ? [value] : []
    })
    .join(' · ')
  return text.length > limit ? `${text.slice(0, limit)}…` : text
}
