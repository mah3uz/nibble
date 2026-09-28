import { describe, expect, it } from 'vitest'
import { activeCount, addableGroups } from '../replicatorSets'
import type { PublishSet, PublishSetGroup } from '../types'

const set = (handle: string, max: number | null = null): PublishSet => ({
  handle,
  display: handle,
  instructions: null,
  icon: null,
  badge: null,
  max,
  fields: [],
})
const group = (handle: string, sets: PublishSet[]): PublishSetGroup => ({
  handle,
  display: handle,
  instructions: null,
  icon: null,
  sets,
})

describe('addableGroups', () => {
  const groups = [group('free', [set('plausible'), set('cloudflare', 1)]), group('once', [set('only', 1)])]

  it('hides a set once it holds its max, so a once-per-page tool cannot be picked twice', () => {
    const picked = addableGroups(groups, [{ type: 'cloudflare' }])
    expect(picked.flatMap((g) => g.sets.map((s) => s.handle))).toEqual(['plausible', 'only'])
  })

  it('counts a paused row against the max, since the server does too', () => {
    expect(addableGroups(groups, [{ type: 'cloudflare', enabled: false }])[0]!.sets.map((s) => s.handle)).toEqual([
      'plausible',
    ])
  })

  it('drops a group left with nothing to add, so the picker shows no empty heading', () => {
    expect(addableGroups(groups, [{ type: 'only' }]).map((g) => g.handle)).toEqual(['free'])
  })
})

describe('activeCount', () => {
  it('leaves paused rows out, so a tab label counts only what runs on the site', () => {
    expect(activeCount([{ type: 'a' }, { type: 'b', enabled: false }, { type: 'c', enabled: true }])).toBe(2)
    expect(activeCount(null)).toBe(0)
  })
})
