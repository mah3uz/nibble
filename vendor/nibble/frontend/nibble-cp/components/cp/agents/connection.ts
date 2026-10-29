import { timeAgo } from '@/lib/format'

type Facts = {
  kind: string
  via: string | null
  last_used_at: string | null
  last_used_ip: string | null
  expires_at: string
}

export const PRESET_LABELS: Record<string, string> = {
  read: 'Read',
  draft: 'Draft',
  everything: 'Everything',
  custom: 'Custom',
}

const VIA: Record<string, string> = { browser: 'In a browser', device: 'With a code', token: 'Token for a script' }

export const connectionVia = (connection: Facts) => (connection.via && VIA[connection.via]) || '—'

export const lastUsed = (connection: Facts) =>
  connection.last_used_at
    ? `${timeAgo(connection.last_used_at)}${connection.last_used_ip ? ` from ${connection.last_used_ip}` : ''}`
    : 'Never'

// An app's end moves ahead each time it is used; a script token's is fixed.
export const connectionEnds = (connection: Facts) =>
  `${timeAgo(connection.expires_at)}${connection.kind === 'app' ? ' unless used' : ''}`
