// The locale comes from the server (the cp.format_locale shared prop) so SSR and the browser render the same text.
let locale = 'en'

export function setFormatLocale(tag: unknown) {
  try {
    locale = typeof tag === 'string' && tag ? Intl.getCanonicalLocales(tag)[0] : 'en'
  } catch {
    locale = 'en'
  }
}

export const formatLocale = () => locale

export function formatNumber(num: number): string {
  if (num >= 1e9) return (num / 1e9).toFixed(1) + 'B+'
  if (num >= 1e6) return (num / 1e6).toFixed(1) + 'M+'
  return num.toLocaleString(locale)
}

const MONTHS = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
]

function ordinal(day: number): string {
  if (day % 100 >= 11 && day % 100 <= 13) return `${day}th`
  return `${day}${{ 1: 'st', 2: 'nd', 3: 'rd' }[day % 10] ?? 'th'}`
}

// Formats like date-fns format(date, 'MMMM do, yyyy'), e.g. "May 20th, 2019". Uses the calendar date
// of the ISO string (Sydney time from the server) so SSR and browser agree.
export function humanizedDate(iso: string): string {
  const [year, month, day] = iso.slice(0, 10).split('-').map(Number)
  return `${MONTHS[month - 1]} ${ordinal(day)}, ${year}`
}

export function formatDateTime(iso: string): string {
  return new Date(iso).toLocaleString(locale, { dateStyle: 'medium', timeStyle: 'short' })
}

// Upper-case the first character only
export function capitalize(value: string): string {
  return value.charAt(0).toUpperCase() + value.slice(1)
}

export function statusLabel(value: string): string {
  return capitalize(value.replaceAll('_', ' '))
}

const RELATIVE_UNITS: [Intl.RelativeTimeFormatUnit, number][] = [
  ['year', 31_536_000],
  ['month', 2_592_000],
  ['week', 604_800],
  ['day', 86_400],
  ['hour', 3_600],
  ['minute', 60],
]

// "5 minutes ago", "in 2 days". Browser-only: the result depends on the current time.
export function timeAgo(iso: string, now: number = Date.now()): string {
  const seconds = Math.round((Date.parse(iso) - now) / 1000)
  const format = new Intl.RelativeTimeFormat(locale, { numeric: 'auto' })
  for (const [unit, size] of RELATIVE_UNITS) {
    if (Math.abs(seconds) >= size) return format.format(Math.round(seconds / size), unit)
  }
  return 'just now'
}

export const initials = (name: string | null) =>
  (name ?? '?')
    .split(/\s+/)
    .map((part) => part.charAt(0))
    .join('')
    .slice(0, 2)
    .toUpperCase()
