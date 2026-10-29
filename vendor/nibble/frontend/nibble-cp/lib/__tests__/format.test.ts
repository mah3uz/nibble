import { afterEach, describe, expect, it } from 'vitest'
import { formatDateTime, formatLocale, formatNumber, setFormatLocale, timeAgo } from '../format'

afterEach(() => setFormatLocale('en'))

describe('format locale', () => {
  it('formats numbers and dates in the locale the server sent', () => {
    const iso = '2026-03-04T09:30:00Z'
    const german = new Date(iso).toLocaleString('de-DE', { dateStyle: 'medium', timeStyle: 'short' })
    setFormatLocale('de-DE')
    expect(formatNumber(12345)).toBe('12.345')
    expect(formatDateTime(iso)).toBe(german)
    setFormatLocale('en-US')
    expect(formatNumber(12345)).toBe('12,345')
    expect(formatDateTime(iso)).not.toBe(german)
  })

  it('formats relative times in the locale', () => {
    const now = Date.parse('2026-03-04T00:00:00Z')
    setFormatLocale('de')
    expect(timeAgo('2026-03-02T00:00:00Z', now)).toBe('vorgestern')
    setFormatLocale('en')
    expect(timeAgo('2026-03-02T00:00:00Z', now)).toBe('2 days ago')
  })

  it('falls back to en for a missing or malformed tag', () => {
    setFormatLocale('de')
    setFormatLocale(undefined)
    expect(formatLocale()).toBe('en')
    setFormatLocale('not a locale!')
    expect(formatLocale()).toBe('en')
  })
})
