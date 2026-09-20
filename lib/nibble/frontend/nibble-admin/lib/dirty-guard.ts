import { router } from '@inertiajs/vue3'
import { onBeforeUnmount } from 'vue'
import { useConfirm } from './confirm'
import { addHistoryGuard } from './history-guard'

let skip = false

// Called right before a form's own save visit, so saving doesn't trip its own guard as if the user
// were navigating away. Resets after the one visit it was meant for.
export function skipNextGuard() {
  skip = true
}

export function useDirtyGuard(isDirty: () => boolean, onLeave?: () => void) {
  if (typeof window === 'undefined') return

  const confirm = useConfirm()
  let asking = false
  let currentUrl = window.location.href
  let currentState: unknown = window.history.state

  function ask(leave: () => void) {
    if (asking) return
    asking = true
    confirm({
      title: 'Leave without saving?',
      description: 'You have unsaved changes on this page. Leaving now discards them.',
      confirmText: 'Leave',
      cancelText: 'Stay',
      dangerous: true,
    }).then((ok) => {
      asking = false
      if (!ok) return
      onLeave?.()
      skip = true
      leave()
    })
  }

  const removeBefore = router.on('before', (event) => {
    if (skip) {
      skip = false
      return
    }
    if (!isDirty()) return
    event.preventDefault()
    const visit = event.detail.visit
    ask(() =>
      router.visit(visit.url, {
        method: visit.method,
        data: visit.data,
        replace: visit.replace,
        preserveScroll: visit.preserveScroll,
        preserveState: visit.preserveState,
        only: visit.only,
        headers: visit.headers,
      }),
    )
  })

  const removeNavigate = router.on('navigate', () => {
    currentUrl = window.location.href
    currentState = window.history.state
  })

  const removeHistoryGuard = addHistoryGuard(() => {
    if (skip) {
      skip = false
      return false
    }
    const withoutHash = (href: string) => href.split('#')[0]
    if (!isDirty() || withoutHash(window.location.href) === withoutHash(currentUrl)) return false
    window.history.pushState(currentState, '', currentUrl)
    ask(() => window.history.back())
    return true
  })

  const onBeforeUnload = (event: BeforeUnloadEvent) => {
    if (isDirty()) event.preventDefault()
  }

  window.addEventListener('beforeunload', onBeforeUnload)

  onBeforeUnmount(() => {
    removeBefore()
    removeNavigate()
    removeHistoryGuard()
    window.removeEventListener('beforeunload', onBeforeUnload)
  })
}
