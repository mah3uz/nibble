import { describe, expect, it } from 'vitest'
import { parseHex } from '../color'

describe('parseHex', () => {
  it('accepts a full hex, with or without the #, as the lowercase value the server stores', () => {
    expect(parseHex('#1A2B3C')).toBe('#1a2b3c')
    expect(parseHex(' 1a2b3c ')).toBe('#1a2b3c')
  })

  it("gives nothing for a half-typed value, so '#ab' is never saved", () => {
    expect(parseHex('#ab')).toBeNull()
    expect(parseHex('#abcdeg')).toBeNull()
    expect(parseHex('')).toBeNull()
  })
})
