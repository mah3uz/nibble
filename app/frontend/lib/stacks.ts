import { computed, onScopeDispose, ref, watch, type Ref } from 'vue'

export type StackSize = 'narrow' | 'half' | 'full'

export const FULL_WIDTH_BREAKPOINT = 980

export function stackOffsets(options: { depth: number; count: number; size?: StackSize; windowWidth: number }): {
  offset: number
  left: number
} {
  const { depth, count, size, windowWidth } = options
  if (size === 'full' || windowWidth <= FULL_WIDTH_BREAKPOINT) return { offset: 0, left: 0 }

  const isTop = depth === count
  let offset = Math.max(450 / (count + 1), 80)
  if (isTop && size === 'narrow') offset = windowWidth - 450
  else if (isTop && size === 'half') offset = windowWidth / 2

  return { offset, left: isTop && (size === 'narrow' || size === 'half') ? offset : offset * depth }
}

const openStacks = ref<symbol[]>([])
const hoveredDepth = ref<number | null>(null)

export function useStack(open: Ref<boolean>) {
  const id = Symbol('stack')
  const remove = () => {
    openStacks.value = openStacks.value.filter((stack) => stack !== id)
    if (!openStacks.value.length) hoveredDepth.value = null
  }

  watch(
    open,
    (isOpen) => {
      if (isOpen && !openStacks.value.includes(id)) openStacks.value = [...openStacks.value, id]
      else if (!isOpen) remove()
    },
    { immediate: true },
  )
  onScopeDispose(remove)

  const depth = computed(() => openStacks.value.indexOf(id) + 1)
  const count = computed(() => openStacks.value.length)

  return { depth, count, hoveredDepth }
}
