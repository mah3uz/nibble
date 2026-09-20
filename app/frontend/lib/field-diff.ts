import { diffLines } from 'diff'

// How one field changed in a version. Short single-line values read best as before → after;
// long text and JSON (post bodies, page blocks, SEO) as a line diff with unchanged runs collapsed,
// so a one-word edit in a long post shows as one changed line rather than two full copies.
export type DiffLine = { kind: 'added' | 'removed' | 'context'; text: string } | { kind: 'skipped'; count: number }
export type FieldDiff = { inline: true; before: string; after: string } | { inline: false; lines: DiffLine[] }

const CONTEXT = 2
const INLINE_MAX = 120

const text = (value: unknown) =>
  value === null || value === undefined ? '' : typeof value === 'string' ? value : JSON.stringify(value, null, 2)

// diffLines treats a missing final newline as a changed last line; an empty value has no lines at all.
const terminated = (value: string) => (value === '' || value.endsWith('\n') ? value : `${value}\n`)

export function fieldDiff(before: unknown, after: unknown): FieldDiff {
  const [a, b] = [text(before), text(after)]
  if (!a.includes('\n') && !b.includes('\n') && a.length <= INLINE_MAX && b.length <= INLINE_MAX)
    return { inline: true, before: a, after: b }

  const lines: DiffLine[] = []
  const parts = diffLines(terminated(a), terminated(b))
  parts.forEach((part, index) => {
    const partLines = part.value.replace(/\n$/, '').split('\n')
    if (part.added || part.removed) {
      partLines.forEach((line) => lines.push({ kind: part.added ? 'added' : 'removed', text: line }))
      return
    }
    const head = index === 0 ? 0 : CONTEXT // context after the previous change
    const tail = index === parts.length - 1 ? 0 : CONTEXT // context before the next change
    if (partLines.length <= head + tail) {
      partLines.forEach((line) => lines.push({ kind: 'context', text: line }))
      return
    }
    partLines.slice(0, head).forEach((line) => lines.push({ kind: 'context', text: line }))
    lines.push({ kind: 'skipped', count: partLines.length - head - tail })
    partLines.slice(partLines.length - tail).forEach((line) => lines.push({ kind: 'context', text: line }))
  })
  return { inline: false, lines }
}
