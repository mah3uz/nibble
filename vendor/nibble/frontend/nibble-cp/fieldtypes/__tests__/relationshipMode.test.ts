import { describe, expect, it } from 'vitest'
import {
  chooseLabel,
  latestRequest,
  nextIds,
  normalizeMode,
  pickerFor,
  probeLimit,
  unplacedErrors,
} from '../relationshipMode'

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

describe('picking a related item', () => {
  it('adds a new item, and replaces the one in a single-item field', () => {
    expect(nextIds(['a'], 'b', { single: false, max: 0 })).toEqual(['a', 'b'])
    expect(nextIds(['a'], 'b', { single: true, max: 1 })).toEqual(['b'])
  })

  it("never removes an item that's picked again: removing is the list's X, not a second click", () => {
    expect(nextIds(['a', 'b'], 'a', { single: false, max: 0 })).toEqual(['a', 'b'])
  })

  it('adds nothing past max_items', () => {
    expect(nextIds(['a', 'b'], 'c', { single: false, max: 2 })).toEqual(['a', 'b'])
  })
})

describe('the picker label', () => {
  it('names what is being chosen, with an article for one and without for many', () => {
    expect(chooseLabel('Category', true)).toBe('Choose a category…')
    expect(chooseLabel('Author', true)).toBe('Choose an author…')
    expect(chooseLabel('Related posts', false)).toBe('Choose related posts…')
  })

  it('keeps an acronym as written, and falls back when the field has no name', () => {
    expect(chooseLabel('PDF files', false)).toBe('Choose PDF files…')
    expect(chooseLabel('', false)).toBe('Choose…')
  })
})

describe('create dialog errors', () => {
  it('returns the errors the dialog has no input for, so a refused Create is never silent', () => {
    const errors = { title: 'Taken', rank: 'Too big', icon: "Icon can't be blank." }
    expect(unplacedErrors(errors, ['title', 'rank'])).toEqual(["Icon can't be blank."])
  })
})

describe('latestRequest', () => {
  it('marks an earlier request stale once a later one starts, so its late answer is dropped', () => {
    const start = latestRequest()
    const first = start()
    const second = start()
    expect(first()).toBe(false)
    expect(second()).toBe(true)
  })
})
