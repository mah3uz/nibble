import { describe, expect, it } from 'vitest'
import { fieldDiff } from '../field-diff'

describe('fieldDiff', () => {
  it('shows short values as before → after', () => {
    expect(fieldDiff('Old title', 'New title')).toEqual({ inline: true, before: 'Old title', after: 'New title' })
    expect(fieldDiff(null, 'Created')).toEqual({ inline: true, before: '', after: 'Created' })
  })

  // A one-word edit deep in a long post body must not bury the change among hundreds of unchanged lines.
  it('collapses unchanged runs of long JSON to two lines of context around each change', () => {
    const before = { content: Array.from({ length: 20 }, (_, i) => `paragraph ${i}`) }
    const after = { content: before.content.map((p, i) => (i === 10 ? 'paragraph ten, edited' : p)) }
    const { lines } = fieldDiff(before, after) as {
      inline: false
      lines: { kind: string; text?: string; count?: number }[]
    }

    expect(lines.filter((l) => l.kind === 'removed').map((l) => l.text)).toEqual(['    "paragraph 10",'])
    expect(lines.filter((l) => l.kind === 'added').map((l) => l.text)).toEqual(['    "paragraph ten, edited",'])
    expect(lines.filter((l) => l.kind === 'context')).toHaveLength(4)
    expect(lines[0]).toEqual({ kind: 'skipped', count: 10 }) // `{`, `"content": [`, paragraphs 0–7
    expect(lines.at(-1)?.kind).toBe('skipped')
  })

  it('shows every line of a newly created long value as added, with no phantom removed line', () => {
    const { lines } = fieldDiff(undefined, 'line one\nline two') as { inline: false; lines: { kind: string }[] }
    expect(lines.map((l) => l.kind)).toEqual(['added', 'added'])
  })
})
