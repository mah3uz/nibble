import type { ListingProps, ListingRow } from '@/components/cp/listing/types'
import type { PublishBlueprint } from '@/components/cp/publish/context'

export type AssetRow = ListingRow & {
  filename: string
  title: string
  kind: string
  extension: string
  thumbnail: string | null
  url: string
  size: number
  updated_at: string
  width: number | null
  height: number | null
  duration: number | null
  alt: string | null
  folder: string
  usage_count: number
}

export type AssetFolderItem = { path: string; name: string }

export type Abilities = { upload: boolean; edit: boolean; delete: boolean }

export type BrowseResponse = {
  listing: Omit<ListingProps, 'rows'> & { rows: AssetRow[] }
  folders: AssetFolderItem[]
  folder: string
  folder_options: { value: string; label: string }[]
  asset_id: number | null
  can: Abilities
}

export type ImageEdits = {
  crop?: { x: number; y: number; width: number; height: number }
  rotate?: number
  flip?: 'horizontal' | 'vertical'
}

export type AssetUsage = { type: string; title: string; field: string; edit_url: string | null }

export type AssetDetail = {
  asset: AssetRow & {
    mime: string
    focal: { x: number; y: number } | null
    focal_zoom: number
    edits: ImageEdits
    tags: string[]
    created_at: string
    preview: string
    download_url: string
    lock_version: number
  }
  blueprint: PublishBlueprint
  values: Record<string, unknown>
  field_meta: Record<string, unknown>
  usage: AssetUsage[]
  folder_options: { value: string; label: string }[]
  can: Abilities
}

export class RequestError extends Error {
  constructor(
    message: string,
    readonly status: number,
    readonly body: Record<string, unknown>,
  ) {
    super(message)
  }
}

export async function request<T>(method: string, url: string, body?: unknown): Promise<T> {
  const csrf = document.querySelector<HTMLMetaElement>('meta[name=csrf-token]')?.content ?? ''
  const response = await fetch(url, {
    method,
    headers: { Accept: 'application/json', 'Content-Type': 'application/json', 'X-CSRF-Token': csrf },
    body: body === undefined ? undefined : JSON.stringify(body),
  })
  const json = response.status === 204 ? {} : await response.json().catch(() => ({}))
  if (!response.ok)
    throw new RequestError(firstError(json) ?? `Request failed (${response.status})`, response.status, json)
  return json as T
}

function firstError(body: Record<string, unknown>): string | null {
  if (typeof body.error === 'string') return body.error
  const errors = body.errors as Record<string, string[]> | undefined
  const [field, messages] = Object.entries(errors ?? {})[0] ?? []
  return field ? `${field === 'base' || field === 'file' ? '' : `${field} `}${messages?.[0] ?? ''}`.trim() : null
}

export function browseUrl(params: Record<string, string | number | null | undefined>) {
  const query = new URLSearchParams()
  for (const [key, value] of Object.entries(params))
    if (value !== null && value !== undefined && value !== '') query.set(key, String(value))
  return `/cp/media${query.size ? `?${query}` : ''}`
}

export function formatBytes(bytes: number) {
  if (bytes < 1024) return `${bytes} B`
  const units = ['KB', 'MB', 'GB']
  let value = bytes / 1024
  let unit = 0
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024
    unit += 1
  }
  return `${value < 10 ? value.toFixed(2).replace(/\.?0+$/, '') : Math.round(value)} ${units[unit]}`
}

export function formatDuration(seconds: number | null) {
  if (!seconds) return ''
  const whole = Math.round(seconds)
  return `${Math.floor(whole / 60)}:${String(whole % 60).padStart(2, '0')}`
}

export function relativeTime(iso: string) {
  const seconds = (new Date(iso).getTime() - Date.now()) / 1000
  const units: [Intl.RelativeTimeFormatUnit, number][] = [
    ['year', 31536000],
    ['month', 2592000],
    ['day', 86400],
    ['hour', 3600],
    ['minute', 60],
  ]
  const [unit, size] = units.find(([, length]) => Math.abs(seconds) >= length) ?? ['second', 1]
  return new Intl.RelativeTimeFormat('en', { numeric: 'auto' }).format(Math.round(seconds / size), unit)
}
