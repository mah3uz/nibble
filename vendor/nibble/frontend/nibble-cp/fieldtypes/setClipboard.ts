import { onMounted, ref } from 'vue'
import type { PublishSet, PublishSetGroup } from './types'

export type CopiedSet = { type: string; values: Record<string, unknown>; meta: Record<string, unknown> }

const KEY = 'nibble:copied-set'
const copied = ref<CopiedSet | null>(null)
let listening = false

function isObject(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value)
}

export function parseCopiedSet(raw: string | null): CopiedSet | null {
  try {
    const parsed: unknown = raw ? JSON.parse(raw) : null
    if (!isObject(parsed) || typeof parsed.type !== 'string' || !isObject(parsed.values)) return null
    return { type: parsed.type, values: parsed.values, meta: isObject(parsed.meta) ? parsed.meta : {} }
  } catch {
    return null
  }
}

function read() {
  try {
    return parseCopiedSet(window.localStorage.getItem(KEY))
  } catch {
    return null
  }
}

// Read on mount rather than at import, so the server-rendered page and the first client render agree.
export function useCopiedSet() {
  onMounted(() => {
    copied.value = read()
    if (listening) return
    listening = true
    window.addEventListener('storage', (event) => {
      if (event.key === KEY) copied.value = read()
    })
  })
  return copied
}

export function copySet(set: CopiedSet) {
  copied.value = set
  try {
    window.localStorage.setItem(KEY, JSON.stringify(set))
  } catch {
    return
  }
}

export function pasteTarget(groups: PublishSetGroup[], set: CopiedSet | null): PublishSet | null {
  if (!set) return null
  return groups.flatMap((group) => group.sets).find((candidate) => candidate.handle === set.type) ?? null
}

export function pastedContent(target: PublishSet, set: CopiedSet) {
  const handles = new Set(target.fields.map((field) => field.handle))
  const pick = (source: Record<string, unknown>) =>
    Object.fromEntries(Object.entries(source).filter(([handle]) => handles.has(handle)))
  return { values: pick(set.values), meta: pick(set.meta) }
}
