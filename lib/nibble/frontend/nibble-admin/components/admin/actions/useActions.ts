import { router } from '@inertiajs/vue3'
import { useConfirm } from '@/lib/confirm'
import type { ListingAction } from '../listing/types'

export function useActions(resource: string) {
  const confirm = useConfirm()

  async function run(action: ListingAction, ids: number[]) {
    let values: Record<string, string> = {}
    if (action.confirm || action.dangerous || action.fields.length) {
      const title = (action.confirm ?? `${action.label}?`).replace('{count}', String(ids.length))
      const fields = action.fields.map((field) => ({
        handle: field.handle,
        label: field.label,
        options: field.options ?? [],
      }))
      const result = await confirm({ title, confirmText: action.label, dangerous: action.dangerous, fields })
      if (!result) return
      values = result
    }
    router.post('/admin/actions', { resource, handle: action.handle, ids, values }, { preserveScroll: true })
  }

  return { run }
}
