import { describe, expect, it } from 'vitest'
import { dateWidthClass, decimalText, offersFullscreen, showsPreviews } from '../display'
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

  it('gives a date with a time zone the whole field, since the zone name needs the room', () => {
    expect(dateWidthClass({ time_enabled: true, time_zone: 'Europe/London' })).not.toContain('max-w-xs')
    expect(dateWidthClass({ time_enabled: true })).toContain('max-w-xs')
  })
})

describe('decimalText', () => {
  it('shows a saved number with the places the field keeps, so 10.5 reads as a price', () => {
    expect(decimalText(10.5, 2)).toBe('10.50')
    expect(decimalText(10.5, undefined)).toBe('10.50')
    expect(decimalText(3, 0)).toBe('3')
    expect(decimalText(null, 2)).toBe('')
  })
})
