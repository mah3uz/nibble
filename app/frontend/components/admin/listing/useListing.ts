import { router } from '@inertiajs/vue3'
import { useDebounceFn } from '@vueuse/core'
import { reactive, ref, watch, type Ref } from 'vue'
import { setPreferenceNow, usePreference } from '@/lib/preferences'
import { buildQuery } from './buildQuery'
import type { ListingProps } from './types'

export function useListing(listing: Ref<ListingProps>) {
  const selected = ref<Set<number>>(new Set())

  const q = ref(listing.value.search.value)
  const sort = ref<string | null>(listing.value.sort.column)
  const dir = ref<'asc' | 'desc'>(listing.value.sort.direction)
  const page = ref(listing.value.pagination.page)
  const filterValue = (handle: string) => {
    const filter = listing.value.filters.find((f) => f.handle === handle)
    return filter?.value ?? (filter?.type === 'multi_select' ? [] : '')
  }
  const filters = reactive<Record<string, string | string[]>>(
    Object.fromEntries(listing.value.filters.map((f) => [f.handle, filterValue(f.handle)])),
  )

  const perPage = usePreference(`listings.${listing.value.preference_key}.per_page`, listing.value.pagination.per_page)

  function visit() {
    const params = buildQuery({
      q: q.value,
      sort: sort.value,
      dir: dir.value,
      page: String(page.value),
      per_page: String(perPage.value),
      ...filters,
    })
    router.get(window.location.pathname, params, {
      preserveState: true,
      preserveScroll: true,
      replace: true,
      only: ['listing'],
    })
  }

  const debouncedVisit = useDebounceFn(visit, 300)
  watch(q, () => {
    page.value = 1
    debouncedVisit()
  })

  function setFilter(handle: string, value: string | string[] | null) {
    const filter = listing.value.filters.find((f) => f.handle === handle)
    filters[handle] = value ?? (filter?.type === 'multi_select' ? [] : '')
    page.value = 1
    selected.value = new Set()
    visit()
  }

  function setSort(handle: string) {
    if (sort.value === handle) dir.value = dir.value === 'asc' ? 'desc' : 'asc'
    else {
      sort.value = handle
      dir.value = 'asc'
    }
    visit()
  }

  function setPage(newPage: number) {
    page.value = newPage
    selected.value = new Set()
    visit()
  }

  function setPerPage(value: number) {
    perPage.value = value
    page.value = 1
    visit()
  }

  // Must be saved before reload, not debounced, or the reload can race the write.
  async function setColumns(handles: string[]) {
    await setPreferenceNow(`listings.${listing.value.preference_key}.columns`, handles)
    router.reload({ only: ['listing'] })
  }

  function toggleSelected(id: number, value?: boolean) {
    const next = new Set(selected.value)
    if (value ?? !next.has(id)) next.add(id)
    else next.delete(id)
    selected.value = next
  }

  function toggleAll(ids: number[], value?: boolean) {
    selected.value = (value ?? selected.value.size < ids.length) ? new Set(ids) : new Set()
  }

  function clearSelection() {
    selected.value = new Set()
  }

  return {
    q,
    sort,
    dir,
    page,
    filters,
    perPage,
    selected,
    visit,
    setFilter,
    setSort,
    setPage,
    setPerPage,
    setColumns,
    toggleSelected,
    toggleAll,
    clearSelection,
  }
}
