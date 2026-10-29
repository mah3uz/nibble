import { describe, expect, it } from 'vitest'
import { parseCopiedSet, pastedContent, pasteTarget, type CopiedSet } from '../setClipboard'
import type { PublishField, PublishSet, PublishSetGroup } from '../types'

const field = (handle: string) => ({ handle }) as PublishField
const set = (handle: string, fields: string[] = []): PublishSet => ({
  handle,
  display: handle.toUpperCase(),
  instructions: null,
  icon: null,
  badge: null,
  max: null,
  fields: fields.map(field),
})
const group = (sets: PublishSet[]): PublishSetGroup => ({
  handle: 'main',
  display: null,
  instructions: null,
  icon: null,
  sets,
})
const copied = (type: string, values = {}, meta = {}): CopiedSet => ({ type, values, meta })

describe('pasteTarget', () => {
  const groups = [group([set('hero')]), group([set('quote')])]

  it('offers a copied block to a field that has a set with its handle, in any group', () => {
    expect(pasteTarget(groups, copied('quote'))?.handle).toBe('quote')
  })

  it('offers nothing when the field has no such set, or nothing was copied', () => {
    expect(pasteTarget(groups, copied('gallery'))).toBeNull()
    expect(pasteTarget(groups, null)).toBeNull()
  })

  it('offers nothing once the set is at its max, because the picker is given only the sets with room', () => {
    expect(pasteTarget([], copied('hero'))).toBeNull()
  })
})

describe('pastedContent', () => {
  it("keeps only the values and meta of the target set's fields, references as they are", () => {
    const target = set('image', ['image', 'caption'])
    const source = copied(
      'image',
      { image: ['asset-1'], caption: 'Dog', retired: 'x' },
      { image: { data: [1] }, retired: {} },
    )

    expect(pastedContent(target, source)).toEqual({
      values: { image: ['asset-1'], caption: 'Dog' },
      meta: { image: { data: [1] } },
    })
  })
})

describe('parseCopiedSet', () => {
  it('reads what Copy block stored', () => {
    expect(parseCopiedSet(JSON.stringify(copied('hero', { title: 'Hi' })))).toEqual(copied('hero', { title: 'Hi' }))
  })

  it('ignores anything else in storage rather than offering a broken paste', () => {
    expect(parseCopiedSet(null)).toBeNull()
    expect(parseCopiedSet('not json')).toBeNull()
    expect(parseCopiedSet(JSON.stringify({ type: 3, values: {} }))).toBeNull()
    expect(parseCopiedSet(JSON.stringify({ type: 'hero', values: [] }))).toBeNull()
  })
})
