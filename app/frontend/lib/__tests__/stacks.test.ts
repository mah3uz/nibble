import { describe, expect, test } from 'vitest'
import { stackOffsets } from '../stacks'

describe('stackOffsets', () => {
  test('a single sheet leaves a 225px strip of the page visible, like one Statamic stack', () => {
    expect(stackOffsets({ depth: 1, count: 1, windowWidth: 1440 })).toEqual({ offset: 225, left: 225 })
  })

  test('each deeper sheet sits one offset further right, so every sheet underneath peeks out', () => {
    const lower = stackOffsets({ depth: 1, count: 2, windowWidth: 1440 })
    const upper = stackOffsets({ depth: 2, count: 2, windowWidth: 1440 })
    expect(lower.left).toBe(150)
    expect(upper.left).toBe(300)
    expect(upper.left - lower.left).toBe(upper.offset)
  })

  test('the peek strip never shrinks below 80px however many sheets are stacked', () => {
    expect(stackOffsets({ depth: 1, count: 9, windowWidth: 1440 }).offset).toBe(80)
  })

  test('a narrow sheet on top is 450px wide, but once covered it falls back to the shared offset', () => {
    expect(stackOffsets({ depth: 1, count: 1, size: 'narrow', windowWidth: 1440 }).left).toBe(990)
    expect(stackOffsets({ depth: 1, count: 2, size: 'narrow', windowWidth: 1440 }).left).toBe(150)
  })

  test('a half sheet on top covers the right half of the window', () => {
    expect(stackOffsets({ depth: 1, count: 1, size: 'half', windowWidth: 1440 }).left).toBe(720)
  })

  test('small windows and full sheets use the whole width, so nothing is squeezed off screen', () => {
    expect(stackOffsets({ depth: 2, count: 2, windowWidth: 900 }).left).toBe(0)
    expect(stackOffsets({ depth: 1, count: 1, size: 'full', windowWidth: 1440 }).left).toBe(0)
  })
})
