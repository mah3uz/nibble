type QueryValue = string | string[] | undefined | null

// dir and per_page are sent even when they look like defaults: the server's defaults are per collection and user.
export function buildQuery(params: Record<string, QueryValue>): Record<string, string | string[]> {
  const query: Record<string, string | string[]> = {}
  for (const [key, value] of Object.entries(params)) {
    if (value === undefined || value === null || value === '') continue
    if (Array.isArray(value) && value.length === 0) continue
    if (key === 'page' && value === '1') continue
    query[key] = value
  }
  return query
}
