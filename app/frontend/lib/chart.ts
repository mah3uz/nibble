export type Point = [number, number]

// Monotone cubic interpolation keeps the curve from dipping below zero between points.
export function smoothPath(points: Point[]): string {
  if (points.length < 2) return points.length ? `M${points[0][0]},${points[0][1]}` : ''
  const n = points.length
  const dx = points.slice(1).map((p, i) => p[0] - points[i][0])
  const slope = points.slice(1).map((p, i) => (p[1] - points[i][1]) / dx[i])
  const tangent = points.map((_, i) => {
    if (i === 0) return slope[0]
    if (i === n - 1) return slope[n - 2]
    return slope[i - 1] * slope[i] <= 0 ? 0 : (2 * slope[i - 1] * slope[i]) / (slope[i - 1] + slope[i])
  })
  let d = `M${points[0][0]},${points[0][1]}`
  for (let i = 0; i < n - 1; i++) {
    const [x0, y0] = points[i]
    const [x1, y1] = points[i + 1]
    const h = dx[i] / 3
    d += `C${x0 + h},${y0 + tangent[i] * h} ${x1 - h},${y1 - tangent[i + 1] * h} ${x1},${y1}`
  }
  return d
}

export function niceMax(value: number): number {
  if (value <= 4) return 4
  const magnitude = 10 ** Math.floor(Math.log10(value))
  const step = [1, 2, 2.5, 5, 10].find((f) => f * magnitude * 4 >= value) ?? 10
  return step * magnitude * 4
}

export function dayLabels(
  start: string,
  count: number,
  options: Intl.DateTimeFormatOptions = { month: 'short', day: 'numeric' },
): string[] {
  const [y, m, d] = start.split('-').map(Number)
  const format = new Intl.DateTimeFormat('en-AU', options)
  return Array.from({ length: count }, (_, i) => format.format(new Date(y, m - 1, d + i)))
}
