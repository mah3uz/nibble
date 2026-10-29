export function ratingAfterKey(key: string, current: number, max: number): number | null | undefined {
  switch (key) {
    case 'ArrowRight':
    case 'ArrowUp':
      return Math.min(max, current + 1)
    case 'ArrowLeft':
    case 'ArrowDown':
      return Math.max(1, current - 1)
    case 'Home':
      return 1
    case 'End':
      return max
    case 'Backspace':
    case 'Delete':
      return null
    default:
      return undefined
  }
}
