import { usePage } from '@inertiajs/vue3'
import { ref, watch, type Ref } from 'vue'
import { toast } from 'vue-sonner'

type PreferencesProps = { admin: { preferences: Record<string, unknown> } }

const SAVE_DELAY_MS = 500

// One ref per key, so every usePreference caller sees a change immediately.
const cache = new Map<string, Ref<unknown>>()

function deepGet(object: Record<string, unknown>, key: string): unknown {
  return key.split('.').reduce<unknown>((value, segment) => {
    return value && typeof value === 'object' ? (value as Record<string, unknown>)[segment] : undefined
  }, object)
}

export function usePreference<T>(key: string, fallback: T): Ref<T> {
  const existing = cache.get(key)
  if (existing) return existing as Ref<T>

  const page = usePage<PreferencesProps>()
  const initial = deepGet(page.props.admin.preferences, key)
  const value = ref((initial === undefined ? fallback : initial) as T) as Ref<T>
  cache.set(key, value as Ref<unknown>)

  let timeout: ReturnType<typeof setTimeout> | undefined
  watch(value, (newValue) => {
    clearTimeout(timeout)
    timeout = setTimeout(() => save(key, newValue), SAVE_DELAY_MS)
  })

  return value
}

export async function setPreferenceNow(key: string, value: unknown) {
  const existing = cache.get(key)
  if (existing) existing.value = value
  await save(key, value)
}

async function save(key: string, value: unknown) {
  const csrf = document.querySelector<HTMLMetaElement>('meta[name=csrf-token]')?.content ?? ''
  const response = await fetch('/admin/preferences', {
    method: 'PATCH',
    headers: { 'Content-Type': 'application/json', Accept: 'application/json', 'X-CSRF-Token': csrf },
    body: JSON.stringify({ key, value }),
  })
  if (response.ok) return

  console.error(`Saving preference "${key}" failed (${response.status})`)
  toast.error("That setting couldn't be saved.")
}
