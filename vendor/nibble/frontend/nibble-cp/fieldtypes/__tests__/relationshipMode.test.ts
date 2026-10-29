import { describe, expect, it } from 'vitest'
import { normalizeMode, pickerFor, probeLimit } from '../relationshipMode'

describe('relationship picker mode', () => {
  it('treats an unset or unknown mode as auto', () => {
    expect(normalizeMode(undefined)).toBe('auto')
    expect(normalizeMode('nonsense')).toBe('auto')
    expect(normalizeMode('stack')).toBe('stack')
  })

  it('auto shows a dropdown for 25 or fewer choices and the search picker beyond that', () => {
    expect(probeLimit('auto')).toBe(26)
    expect(pickerFor('auto', null)).toBe('loading')
    expect(pickerFor('auto', 0)).toBe('select')
    expect(pickerFor('auto', 25)).toBe('select')
    expect(pickerFor('auto', 26)).toBe('search')
  })

  it('select loads up to its cap and falls back to search when the list reaches it', () => {
    expect(pickerFor('select', 49)).toBe('select')
    expect(pickerFor('select', 50)).toBe('search')
  })

  it('default, typeahead and stack never wait on a count', () => {
    expect(probeLimit('default')).toBe(0)
    expect(pickerFor('default', null)).toBe('search')
    expect(pickerFor('typeahead', null)).toBe('typeahead')
    expect(pickerFor('stack', 3)).toBe('stack')
  })
})
