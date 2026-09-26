import { computed } from 'vue'
import { getPath } from '../lib/paths'
import { useContainer } from '../publish/context'

// Values beside a field: the row it lives in, or the whole record for top-level fields.
export function useSiblings(props: { fieldPathPrefix?: string; handle: string }) {
  const container = useContainer()
  const parentPath = computed(() => (props.fieldPathPrefix ?? props.handle).split('.').slice(0, -1).join('.'))
  return computed(() => {
    const parent = parentPath.value ? getPath(container.values.value, parentPath.value) : container.values.value
    return (parent ?? {}) as Record<string, unknown>
  })
}
