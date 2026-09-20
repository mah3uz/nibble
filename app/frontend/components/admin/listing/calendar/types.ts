export type CalendarEntry = {
  id: number
  title: string | null
  status: string
  hour: number
  time: string
  edit_url: string
}

export type CalendarData = {
  scale: 'month' | 'week'
  date: string
  from: string
  to: string
  title: string
  today: string
  days: Record<string, CalendarEntry[]>
}

export type CalendarDay = {
  key: string
  number: number
  outside: boolean
  today: boolean
  weekday: number
  entries: CalendarEntry[]
}

export const WEEKDAYS = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday']

export const parseDay = (value: string) => new Date(`${value}T00:00:00Z`)

export const isoDay = (date: Date) => date.toISOString().slice(0, 10)

export function buildDays(calendar: CalendarData): CalendarDay[] {
  const to = parseDay(calendar.to)
  const month = parseDay(calendar.date).getUTCMonth()
  const days: CalendarDay[] = []
  for (const day = parseDay(calendar.from); day <= to; day.setUTCDate(day.getUTCDate() + 1)) {
    const key = isoDay(day)
    days.push({
      key,
      number: day.getUTCDate(),
      outside: day.getUTCMonth() !== month,
      today: key === calendar.today,
      weekday: day.getUTCDay(),
      entries: calendar.days[key] ?? [],
    })
  }
  return days
}
