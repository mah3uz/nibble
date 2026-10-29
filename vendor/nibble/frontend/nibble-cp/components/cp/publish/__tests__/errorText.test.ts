import { describe, expect, it } from 'vitest'
import { errorText } from '../errorText'

describe('errorText', () => {
  it('names the field once when the message already names it', () => {
    expect(errorText('Title', 'The Title field is required.')).toBe('Title is required.')
    expect(errorText('Title', 'The title field must be at least 5 characters.')).toBe(
      'Title must be at least 5 characters.',
    )
    expect(errorText('Slug', 'Slug is already used by another entry')).toBe('Slug is already used by another entry')
  })

  it('adds the label to a message that does not name the field', () => {
    expect(errorText('Title', 'is too long')).toBe('Title is too long')
  })

  it('leaves a message alone when no field is found for it', () => {
    expect(errorText(null, 'Another page already uses this address: /x.')).toBe(
      'Another page already uses this address: /x.',
    )
  })
})
