import { inject, onBeforeUnmount, provide, ref, type InjectionKey, type Ref } from 'vue'

export type Breadcrumb = { label: string; url?: string }

const key: InjectionKey<Ref<Breadcrumb[]>> = Symbol('breadcrumbs')

// Called once, high in the tree (AdminLayout) — above both the header and every page it renders —
// so a trail set by the page reaches the header, which is its sibling, not its ancestor.
export function provideBreadcrumbs() {
  provide(key, ref<Breadcrumb[]>([]))
}

// Reads the current trail (GlobalHeader).
export function injectBreadcrumbs(): Ref<Breadcrumb[]> {
  return inject(key, ref([]))
}

// Called by a page (via PageHeader) to show its trail in the global header, cleared automatically
// when that page unmounts (e.g. navigating elsewhere) so the next page doesn't inherit it.
export function useBreadcrumbs(trail: Breadcrumb[]) {
  const breadcrumbs = inject(key)
  if (!breadcrumbs) return
  breadcrumbs.value = trail
  onBeforeUnmount(() => {
    breadcrumbs.value = []
  })
}
