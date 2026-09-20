export type ItemSummary = {
  id: string
  title: string
  url?: string | null
  status?: string | null
  edit_url?: string | null
  thumbnail?: string | null
  alt?: string | null
  [key: string]: unknown
}

export async function searchRelationships(
  type: string,
  { query, scope = {}, limit = 20 }: { query: string; scope?: Record<string, unknown>; limit?: number },
): Promise<ItemSummary[]> {
  const params = new URLSearchParams({ q: query, limit: String(limit) })
  for (const [key, value] of Object.entries(scope)) {
    for (const item of Array.isArray(value) ? value : value == null ? [] : [value])
      params.append(`scope[${key}][]`, String(item))
  }
  const response = await fetch(`/admin/nibble/relationships/${encodeURIComponent(type)}?${params}`, {
    headers: { Accept: 'application/json' },
  })
  if (!response.ok) throw new Error(`Couldn't search ${type} (${response.status})`)
  return ((await response.json()) as { data: ItemSummary[] }).data
}
