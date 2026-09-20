import type { Breadcrumb } from './breadcrumbs'
import type { NavSection } from './admin'

const STORAGE_KEY = 'admin.recentVisits'
const MAX_RECENT = 5

export type RecentVisit = { url: string; label: string }

// sessionStorage can throw (private browsing, storage disabled) or simply not exist (this module's
// own tests run without a DOM, like lib/shortcuts.ts) — every access goes through this guard so a
// storage failure just means recent visits don't persist, never a crash.
function storage(): Storage | null {
  try {
    return typeof sessionStorage === 'undefined' ? null : sessionStorage
  } catch {
    return null
  }
}

export function getRecentVisits(): RecentVisit[] {
  const store = storage()
  if (!store) return []
  try {
    const raw = store.getItem(STORAGE_KEY)
    return raw ? (JSON.parse(raw) as RecentVisit[]) : []
  } catch {
    return []
  }
}

// The page's own last breadcrumb (set via PageHeader) is the best label when there is one. Today
// every admin/*_controller.rb only sends a one-crumb trail (the section, e.g. "Pages"), not the
// record's own title — so in practice this currently matches the nav fallback below, but it will
// pick up a richer label automatically the day a controller adds a second crumb. Otherwise, fall
// back to the longest-matching nav item (same "which section is this URL under" rule NavSidebar
// uses for highlighting), then to the URL itself for a page with neither (there's always at least
// a Dashboard match).
export function labelForVisit(url: string, breadcrumbs: Breadcrumb[], nav: NavSection[]): string {
  const last = breadcrumbs.at(-1)
  if (last?.label) return last.label

  const flat = nav.flatMap((section) => section.items.flatMap((item) => [item, ...(item.children ?? [])]))
  const match = flat
    .filter((item) => url === item.active || url.startsWith(`${item.active}/`))
    .sort((a, b) => b.active.length - a.active.length)[0]
  if (match) return match.title

  const cleaned = url
    .replace(/^\/admin\/?/, '')
    .replace(/[/-]+/g, ' ')
    .trim()
  return cleaned || 'Dashboard'
}

export function recordVisit(url: string, label: string) {
  const store = storage()
  if (!store) return

  const deduped = getRecentVisits().filter((visit) => visit.url !== url)
  const updated = [{ url, label }, ...deduped].slice(0, MAX_RECENT)
  try {
    store.setItem(STORAGE_KEY, JSON.stringify(updated))
  } catch {
    // Storage full or disabled: recent visits just don't persist this session.
  }
}

export function removeRecentVisit(url: string) {
  const store = storage()
  if (!store) return

  try {
    store.setItem(STORAGE_KEY, JSON.stringify(getRecentVisits().filter((visit) => visit.url !== url)))
  } catch {
    return
  }
}
