import type { Node } from '@tiptap/pm/model'

const WORDS_PER_MINUTE = 265
const IMAGE_SECONDS = 12

export function readingTime(doc: Node): number {
  const words = (doc.textBetween(0, doc.content.size, ' ', ' ').match(/\w+/g) ?? []).length
  let images = 0
  doc.descendants((node) => {
    if (node.type.name === 'image') images++
  })
  // The first image takes 12s and each later one a second less, never under 3s.
  const imageSeconds =
    images > 10
      ? (images / 2) * (IMAGE_SECONDS + 3) + (images - 10) * 3
      : (images / 2) * (2 * IMAGE_SECONDS + 1 - images)
  return Math.max(1, Math.round(((words / WORDS_PER_MINUTE) * 60 + imageSeconds) / 60))
}
