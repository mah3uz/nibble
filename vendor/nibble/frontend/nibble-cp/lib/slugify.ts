export function slugify(text: string, separator = '-'): string {
  const escaped = separator.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')
  return text
    .normalize('NFKD')
    .replace(/[̀-ͯ]/g, '')
    .toLowerCase()
    .trim()
    .replace(/[^a-z0-9]+/g, separator)
    .replace(new RegExp(`^${escaped}+|${escaped}+$`, 'g'), '')
}
