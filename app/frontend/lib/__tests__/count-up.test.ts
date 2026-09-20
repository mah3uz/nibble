import { describe, expect, it } from 'vitest'
import { countAt } from '../count-up'

describe('countAt', () => {
  it('reaches exactly the target at the end of the duration, however large the number', () => {
    expect(countAt(2000, 2000, 0, 2_700_000_000)).toBe(2_700_000_000)
    expect(countAt(5000, 2000, 0, 179_584)).toBe(179_584)
  })

  it('eases out: most of the distance early, small steps near the end', () => {
    const first10 = countAt(200, 2000, 0, 1000)
    const last10 = countAt(2000, 2000, 0, 1000) - countAt(1800, 2000, 0, 1000)
    expect(first10).toBeGreaterThan(200)
    expect(last10).toBeLessThan(5)
  })

  it('never goes backwards or past the target', () => {
    let previous = 0
    for (let t = 0; t <= 2000; t += 16) {
      const value = countAt(t, 2000, 0, 4603)
      expect(value).toBeGreaterThanOrEqual(previous)
      expect(value).toBeLessThanOrEqual(4603)
      previous = value
    }
  })

  it('starts at the start value', () => {
    expect(countAt(0, 2000, 0, 22)).toBe(0)
  })
})
