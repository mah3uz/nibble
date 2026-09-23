import { onScopeDispose, ref, watch, type Ref } from 'vue'

const BASE = 100
let openCount = 0
let sequence = 0

export function useLayerZIndex(open: Ref<boolean>) {
  const zIndex = ref(BASE)
  let counted = false

  const release = () => {
    if (!counted) return
    counted = false
    openCount--
    if (openCount === 0) sequence = 0
  }

  watch(
    open,
    (isOpen) => {
      if (isOpen && !counted) {
        counted = true
        openCount++
        zIndex.value = BASE + ++sequence * 2
      } else if (!isOpen) {
        release()
      }
    },
    { immediate: true },
  )
  onScopeDispose(release)

  return zIndex
}
