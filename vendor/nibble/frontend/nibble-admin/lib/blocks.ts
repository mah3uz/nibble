// eslint-disable-next-line @typescript-eslint/no-explicit-any
export type RenderedBlock = { id: string; type: string; data: Record<string, any> }

export function escapeHtml(value: string): string {
  return value.replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c]!)
}
