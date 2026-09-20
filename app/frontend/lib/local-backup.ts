import { useDebounceFn } from '@vueuse/core'
import { onMounted, ref, watch } from 'vue'

export type LocalBackup = { values: Record<string, unknown>; savedAt: number; base: string | null }

const PREFIX = 'nibble:backup:'
const IGNORED = ['lock_version']

function read(key: string): LocalBackup | null {
  try {
    const raw = window.localStorage.getItem(PREFIX + key)
    return raw ? (JSON.parse(raw) as LocalBackup) : null
  } catch {
    return null
  }
}

function write(key: string, backup: LocalBackup) {
  try {
    window.localStorage.setItem(PREFIX + key, JSON.stringify(backup))
  } catch {
    return
  }
}

function remove(key: string) {
  try {
    window.localStorage.removeItem(PREFIX + key)
  } catch {
    return
  }
}

function comparable(values: Record<string, unknown>) {
  return JSON.stringify(Object.fromEntries(Object.entries(values).filter(([key]) => !IGNORED.includes(key))))
}

export function useLocalBackup(options: {
  key: () => string
  values: Record<string, unknown>
  isDirty: () => boolean
  base: () => string | null
}) {
  const available = ref<LocalBackup | null>(null)

  const persist = useDebounceFn(() => {
    if (options.isDirty())
      write(options.key(), {
        values: JSON.parse(comparable(options.values)),
        savedAt: Date.now(),
        base: options.base(),
      })
    else remove(options.key())
  }, 500)

  onMounted(() => {
    const backup = read(options.key())
    if (backup && comparable(backup.values) !== comparable(options.values)) available.value = backup
    else remove(options.key())
    watch(() => options.values, persist, { deep: true })
  })

  function restore() {
    if (!available.value) return
    Object.assign(options.values, available.value.values)
    available.value = null
  }

  function discard() {
    available.value = null
    if (!options.isDirty()) remove(options.key())
  }

  function clear() {
    available.value = null
    remove(options.key())
  }

  return { available, restore, discard, clear }
}
