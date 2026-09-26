import { expect, test } from 'vitest'
import { fuzzyMatch } from '../fuzzy'

test('a contiguous match ranks above a scattered one, so typing a screen name surfaces that screen first', () => {
  const exact = fuzzyMatch('Redirects', 'red')!
  const scattered = fuzzyMatch('Reorder dashboard', 'red')!
  expect(exact.score).toBeGreaterThan(scattered.score)
})

test('letters in order but not adjacent still match, like Statamic’s fuzzy palette', () => {
  expect(fuzzyMatch('Navigation', 'nvg')).not.toBeNull()
})

test('letters that are not all present exclude the item instead of showing an unrelated result', () => {
  expect(fuzzyMatch('Posts', 'pz')).toBeNull()
})

test('highlight segments rebuild the original text exactly and mark only the matched characters', () => {
  const { segments } = fuzzyMatch('Site settings', 'set')!
  expect(segments.map((s) => s.text).join('')).toBe('Site settings')
  expect(segments.filter((s) => s.match).map((s) => s.text)).toEqual(['set'])
})
