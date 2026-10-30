import { useLocale, useSite } from '@nibble'

const DEFAULT_OPTIONS: Intl.DateTimeFormatOptions = { month: 'short', day: 'numeric', year: 'numeric' }

export function formatDate(
  value: string | null | undefined,
  options: Intl.DateTimeFormatOptions = DEFAULT_OPTIONS,
  locale = 'en',
  timeZone = 'UTC',
) {
  return value ? new Intl.DateTimeFormat(locale, { timeZone, ...options }).format(new Date(value)) : ''
}

export function useFormatDate() {
  const locale = useLocale()
  const site = useSite()
  return (value: string | null | undefined, options: Intl.DateTimeFormatOptions = DEFAULT_OPTIONS) =>
    formatDate(value, options, locale.value, site.value?.time_zone)
}

export function isoDate(value: string | null | undefined) {
  return value ? value.slice(0, 10) : undefined
}
