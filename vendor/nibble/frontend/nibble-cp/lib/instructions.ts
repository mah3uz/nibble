export type InstructionPart = { text: string; href?: string }

const LINK = /\[([^\]]+)\]\((https:\/\/[^\s)]+)\)/g

export function instructionParts(text: string): InstructionPart[] {
  const parts: InstructionPart[] = []
  let last = 0
  for (const match of text.matchAll(LINK)) {
    if (match.index > last) parts.push({ text: text.slice(last, match.index) })
    parts.push({ text: match[1]!, href: match[2]! })
    last = match.index + match[0].length
  }
  if (last < text.length) parts.push({ text: text.slice(last) })
  return parts
}
