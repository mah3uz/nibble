import { describe, expect, it } from 'vitest'
import { dateWidthClass, offersFullscreen, showsPreviews } from '../display'
import { collapsedPreview } from '../replicatorSets'
import type { PublishField } from '../types'

describe('offersFullscreen', () => {
  it('offers the button unless the field turns it off', () => {
    expect(offersFullscreen({})).toBe(true)
    expect(offersFullscreen({ fullscreen: true })).toBe(true)
    expect(offersFullscreen({ fullscreen: false })).toBe(false)
  })
})

describe('showsPreviews', () => {
  it('shows previews unless the field turns them off', () => {
    expect(showsPreviews({})).toBe(true)
    expect(showsPreviews({ previews: false })).toBe(false)
  })

  it('leaves a collapsed block with only its name when previews are off', () => {
    const fields = [{ handle: 'title', type: 'text', replicator_preview: true }] as unknown as PublishField[]
    expect(collapsedPreview(fields, { title: 'Hello' }, true)).toBe('Hello')
    expect(collapsedPreview(fields, { title: 'Hello' }, false)).toBe('')
  })
})

describe('dateWidthClass', () => {
  it('keeps the date input compact unless full_width is set', () => {
    expect(dateWidthClass({})).toContain('max-w-xs')
    expect(dateWidthClass({ full_width: false })).toContain('max-w-xs')
    expect(dateWidthClass({ full_width: true })).not.toContain('max-w-xs')
  })
})
