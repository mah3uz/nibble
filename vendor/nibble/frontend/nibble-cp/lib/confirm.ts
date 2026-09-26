import { reactive } from 'vue'

export type ConfirmField = {
  handle: string
  label: string
  options: { value: string; label: string }[]
  value?: string
}

type ConfirmOptions = {
  title: string
  description?: string
  confirmText?: string
  cancelText?: string
  dangerous?: boolean
  fields?: ConfirmField[]
}

const state = reactive<
  ConfirmOptions & {
    open: boolean
    values: Record<string, string>
    resolve: ((value: Record<string, string> | false) => void) | null
  }
>({
  open: false,
  title: '',
  description: undefined,
  confirmText: 'Confirm',
  cancelText: 'Cancel',
  dangerous: false,
  fields: undefined,
  values: {},
  resolve: null,
})

// Read by the single <ConfirmDialog> mounted in CpLayout — there is one dialog for the whole CP,
// not one per caller.
export function useConfirmState() {
  return state
}

export function answerConfirm(ok: boolean) {
  state.resolve?.(ok ? { ...state.values } : false)
  state.open = false
  state.resolve = null
}

// Promise-based replacement for window.confirm: `if (await confirm({ title: '...' })) ...`. Resolves
// with the collected field values (an empty object when there are none — still truthy) on confirm, or
// `false` on dismiss/cancel, so both plain and field-collecting callers can use the same `if (result)`.
export function useConfirm() {
  return (options: ConfirmOptions): Promise<Record<string, string> | false> =>
    new Promise((resolve) => {
      const values = Object.fromEntries(
        (options.fields ?? []).map((field) => [field.handle, field.value ?? field.options[0]?.value ?? '']),
      )
      Object.assign(state, {
        confirmText: 'Confirm',
        cancelText: 'Cancel',
        dangerous: false,
        fields: undefined,
        values,
        ...options,
        open: true,
        resolve,
      })
    })
}
