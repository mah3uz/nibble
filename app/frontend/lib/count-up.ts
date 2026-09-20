export function countAt(elapsed: number, duration: number, start: number, end: number): number {
  if (duration <= 0 || elapsed >= duration) return end
  const progress = Math.max(0, elapsed) / duration
  const eased = 1 - Math.pow(1 - progress, 3)
  return Math.round(start + (end - start) * eased)
}
