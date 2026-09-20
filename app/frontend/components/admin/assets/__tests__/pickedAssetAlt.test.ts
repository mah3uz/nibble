import { describe, expect, it } from 'vitest'
import { resolvePickedAlt } from '../pickedAssetAlt'

describe('resolvePickedAlt', () => {
  it('keeps the existing alt text when picking a replacement image', () => {
    expect(resolvePickedAlt('Clinic exterior', 'Some other default')).toBe('Clinic exterior')
  })

  it('falls back to the asset default when there is no existing alt text', () => {
    expect(resolvePickedAlt('', 'Clinic exterior')).toBe('Clinic exterior')
  })

  it('stays empty when neither the field nor the asset has alt text', () => {
    expect(resolvePickedAlt('', '')).toBe('')
  })
})
