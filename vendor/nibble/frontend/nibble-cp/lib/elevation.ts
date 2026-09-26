export function csrfToken() {
  return document.querySelector<HTMLMetaElement>('meta[name=csrf-token]')?.content ?? ''
}

export async function postJson(url: string, body: Record<string, unknown> = {}) {
  return fetch(url, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', Accept: 'application/json', 'X-CSRF-Token': csrfToken() },
    body: JSON.stringify(body),
  })
}

export async function elevate(password: string) {
  const response = await postJson('/cp/session/elevate', { password })
  if (response.ok) return null
  const body = await response.json().catch(() => ({}))
  return (body.error as string) ?? 'That password was refused.'
}
