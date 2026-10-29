import { describe, expect, it } from 'vitest'
import { statusLabel } from '../format'

describe('statusLabel', () => {
  it('shows a status as a person would say it, not as its stored key', () => {
    expect(statusLabel('in_review')).toBe('In review')
    expect(statusLabel('published')).toBe('Published')
  })
})
