export function formatDate(
  value: string | null | undefined,
  options: Intl.DateTimeFormatOptions = { month: 'short', day: 'numeric', year: 'numeric' },
) {
  return value ? new Intl.DateTimeFormat('en', { timeZone: 'UTC', ...options }).format(new Date(value)) : ''
}

export function isoDate(value: string | null | undefined) {
  return value ? value.slice(0, 10) : undefined
}
