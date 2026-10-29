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
  {
    query,
    scope = {},
    limit = 20,
    offset = 0,
  }: { query: string; scope?: Record<string, unknown>; limit?: number; offset?: number },
): Promise<ItemSummary[]> {
  const params = new URLSearchParams({ q: query, limit: String(limit) })
  if (offset) params.set('offset', String(offset))
  for (const [key, value] of Object.entries(scope)) {
    for (const item of Array.isArray(value) ? value : value == null ? [] : [value])
      params.append(`scope[${key}][]`, String(item))
  }
  const response = await fetch(`/cp/nibble/relationships/${encodeURIComponent(type)}?${params}`, {
    headers: { Accept: 'application/json' },
  })
  if (!response.ok) throw new Error(`Couldn't search ${type} (${response.status})`)
  return ((await response.json()) as { data: ItemSummary[] }).data
}

export type CreateTarget = {
  handle: string
  label: string
  fields: { handle: string; display: string; type: string }[]
}

export async function createRelationship(
  type: string,
  body: { target: string; title: string; values?: Record<string, unknown> },
): Promise<{ item?: ItemSummary; errors?: Record<string, string> }> {
  const csrf = document.querySelector<HTMLMetaElement>('meta[name=csrf-token]')?.content ?? ''
  const response = await fetch(`/cp/nibble/relationships/${encodeURIComponent(type)}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', Accept: 'application/json', 'X-CSRF-Token': csrf },
    body: JSON.stringify(body),
  })
  if (response.status === 422) return { errors: ((await response.json()) as { errors: Record<string, string> }).errors }
  if (!response.ok) throw new Error(`Could not create it (${response.status})`)
  return { item: ((await response.json()) as { data: ItemSummary }).data }
}
