export type Segment = { text: string; match: boolean }

export function fuzzyMatch(text: string, query: string): { score: number; segments: Segment[] } | null {
  const needle = query.trim().toLowerCase()
  if (!needle) return { score: 0, segments: [{ text, match: false }] }

  const haystack = text.toLowerCase()
  const contiguous = haystack.indexOf(needle)
  const matched = new Set<number>()
  let score: number

  if (contiguous >= 0) {
    for (let i = 0; i < needle.length; i++) matched.add(contiguous + i)
    score = 1000 - contiguous
  } else {
    let from = 0
    for (const char of needle) {
      if (char === ' ') continue
      const at = haystack.indexOf(char, from)
      if (at < 0) return null
      matched.add(at)
      from = at + 1
    }
    score = 500 - from
  }

  const segments: Segment[] = []
  for (let i = 0; i < text.length; i++) {
    const match = matched.has(i)
    const last = segments.at(-1)
    if (last && last.match === match) last.text += text[i]
    else segments.push({ text: text[i], match })
  }
  return { score, segments }
}
