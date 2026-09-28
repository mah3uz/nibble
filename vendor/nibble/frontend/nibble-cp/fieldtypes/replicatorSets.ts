import type { PublishSet, PublishSetGroup } from './types'

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
