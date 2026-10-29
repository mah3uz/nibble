export function parseHex(text: string): string | null {
  const value = text.trim().toLowerCase()
  const hex = value.startsWith('#') ? value : `#${value}`
  return /^#[0-9a-f]{6}$/.test(hex) ? hex : null
}
