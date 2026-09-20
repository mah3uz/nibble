type Guard = (event: PopStateEvent) => boolean

const guards = new Set<Guard>()

// Must be registered before Inertia starts, so it runs ahead of Inertia's own popstate listener.
export function installHistoryGuard() {
  if (typeof window === 'undefined') return
  window.addEventListener('popstate', (event) => {
    for (const guard of guards) {
      if (guard(event)) return event.stopImmediatePropagation()
    }
  })
}

export function addHistoryGuard(guard: Guard) {
  guards.add(guard)
  return () => guards.delete(guard)
}
