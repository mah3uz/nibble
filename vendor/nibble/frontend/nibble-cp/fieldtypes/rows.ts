import { onBeforeUnmount } from 'vue'
import { toast } from 'vue-sonner'

export const UNDO_MS = 6000

export function moveRow<T>(rows: T[], from: number, to: number): T[] {
  if (from === to || from < 0 || to < 0 || from >= rows.length || to >= rows.length) return rows
  const next = [...rows]
  next.splice(to, 0, ...next.splice(from, 1))
  return next
}

export function restoreRow<T extends { _id: string }>(rows: T[], row: T, index: number): T[] {
  if (rows.some((existing) => existing._id === row._id)) return rows
  const next = [...rows]
  next.splice(Math.min(index, next.length), 0, row)
  return next
}

export function useUndoToast() {
  const shown = new Set<string | number>()
  onBeforeUnmount(() => shown.forEach((id) => toast.dismiss(id)))

  return (message: string, undo: () => void) => {
    const id = toast(message, {
      duration: UNDO_MS,
      action: { label: 'Undo', onClick: undo },
      onDismiss: () => shown.delete(id),
      onAutoClose: () => shown.delete(id),
    })
    shown.add(id)
  }
}
