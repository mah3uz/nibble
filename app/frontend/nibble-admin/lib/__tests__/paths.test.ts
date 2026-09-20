import { describe, expect, it } from 'vitest'
import { getPath, joinPath, omitPaths, setPath } from '../paths'

describe('paths', () => {
  const values = { title: 'Hi', blocks: [{ id: 'a', items: [{ caption: 'x' }] }, { id: 'b' }] }

  it('reads nested object and array paths', () => {
    expect(getPath(values, 'blocks.0.items.0.caption')).toBe('x')
    expect(getPath(values, 'blocks.5.id')).toBeUndefined()
    expect(getPath(values, '')).toBe(values)
  })

  it('writes a nested value without mutating or re-creating untouched branches', () => {
    const updated = setPath(values, 'blocks.0.items.0.caption', 'y')

    expect(getPath(updated, 'blocks.0.items.0.caption')).toBe('y')
    expect(values.blocks[0]!.items![0]!.caption).toBe('x')
    expect(updated.blocks[1]).toBe(values.blocks[1])
  })

  it('creates missing containers, using arrays for numeric keys', () => {
    expect(setPath({}, 'links.0.url', '/about')).toEqual({ links: [{ url: '/about' }] })
  })

  it('omits hidden field values, deepest first', () => {
    expect(omitPaths({ a: 1, row: { b: 2, c: 3 } }, ['row.b', 'a'])).toEqual({ row: { c: 3 } })
  })

  it('joins only the parts that exist', () => {
    expect(joinPath(undefined, 'blocks', 0, 'title')).toBe('blocks.0.title')
  })
})
