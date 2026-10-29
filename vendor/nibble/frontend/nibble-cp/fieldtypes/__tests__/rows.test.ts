import { describe, expect, it } from 'vitest'
import { moveRow, restoreRow } from '../rows'

const row = (id: string) => ({ _id: id })
const ids = (rows: { _id: string }[]) => rows.map((r) => r._id)

describe('moveRow', () => {
  const rows = [row('a'), row('b'), row('c')]

  it('swaps a row with its neighbour, so Move up and Move down step one place', () => {
    expect(ids(moveRow(rows, 1, 0))).toEqual(['b', 'a', 'c'])
    expect(ids(moveRow(rows, 1, 2))).toEqual(['a', 'c', 'b'])
  })

  it('leaves the list alone past either end, where the menu item is disabled anyway', () => {
    expect(moveRow(rows, 0, -1)).toBe(rows)
    expect(moveRow(rows, 2, 3)).toBe(rows)
  })

  it('does not change the list it was given, since that is the field value Vue holds', () => {
    moveRow(rows, 0, 2)
    expect(ids(rows)).toEqual(['a', 'b', 'c'])
  })
})

describe('restoreRow', () => {
  it('puts an undone removal back where it was, content and all', () => {
    const removed = { _id: 'b', title: 'Kept' }
    expect(restoreRow([row('a'), row('c')], removed, 1)).toEqual([row('a'), removed, row('c')])
  })

  it('appends it when rows after it were removed meanwhile', () => {
    expect(ids(restoreRow([row('a')], row('c'), 2))).toEqual(['a', 'c'])
  })

  it('does nothing when the row is already back, so a second Undo cannot duplicate it', () => {
    const rows = [row('a'), row('b')]
    expect(restoreRow(rows, row('b'), 1)).toBe(rows)
  })
})
