import { router, useForm, usePage } from '@inertiajs/vue3'
import { computed, ref } from 'vue'
import { useCp } from '@/lib/cp'
import { skipNextGuard, useDirtyGuard } from '@/lib/dirty-guard'
import { useLocalBackup } from '@/lib/local-backup'
import { usePreference } from '@/lib/preferences'
import { useShortcut } from '@/lib/shortcuts'
import type { DraftMeta, EditMeta, EditUrls } from './context'

export type Commit = 'save' | 'publish' | 'unpublish' | 'submit' | 'approve' | 'reject' | 'discard' | 'trash'

export type UsePublishFormOptions = {
  resourceKey: string
  urls: EditUrls
  values: Record<string, unknown>
  meta: EditMeta
  draft: DraftMeta
  canPublish: boolean
}

export function usePublishForm(options: UsePublishFormOptions) {
  // The blueprint decides the shape of values, which useForm's static types can't describe.
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  const form = useForm(options.values as any)
  const values = form as unknown as Record<string, unknown>
  const meta = ref<EditMeta>(options.meta)
  const draft = ref<DraftMeta>(options.draft)
  const page = usePage<Record<string, unknown>>()
  // The component outlives the create redirect, so urls captured at setup would still be the collection's.
  const urls = computed<EditUrls>(() => (page.props.urls as EditUrls | undefined) ?? options.urls)
  const submitted = ref<Record<string, unknown>>(options.values)

  const afterSave = usePreference<'continue' | 'listing' | 'create_another'>('after_save', 'continue')
  function afterSaveNavigate() {
    if (afterSave.value === 'listing') router.visit(urls.value.listing)
    else if (afterSave.value === 'create_another' && urls.value.create_another) router.visit(urls.value.create_another)
  }

  function syncFromProps() {
    const freshMeta = page.props.meta as EditMeta | undefined
    if (freshMeta) {
      meta.value = freshMeta
      if ('lock_version' in values) values.lock_version = freshMeta.lock_version
    }
    if ('draft' in page.props) draft.value = page.props.draft as DraftMeta
    form.defaults()
  }

  const urlFor = (commit: Commit) => (commit === 'save' ? urls.value.update : (urls.value[commit] as string | null))

  const cp = useCp()
  const backup = useLocalBackup({
    key: () => `${cp.value.user?.id ?? 'guest'}:${options.resourceKey}:${meta.value.id ?? `new:${urls.value.update}`}`,
    values,
    isDirty: () => form.isDirty,
    base: () => meta.value.updated_at,
  })

  function save(commit: Commit, opts: { message?: string } = {}) {
    const url = urlFor(commit)
    if (!url) return

    form.transform((data: Record<string, unknown>) => {
      submitted.value = data
      return { [options.resourceKey]: { ...data, ...(opts.message ? { message: opts.message } : {}) } }
    })
    skipNextGuard()
    const visit = {
      preserveScroll: true,
      preserveState: true,
      onSuccess: () => {
        backup.clear()
        syncFromProps()
        if (commit === 'save') afterSaveNavigate()
      },
    }
    if (meta.value.id == null) form.post(urls.value.update, visit)
    else if (commit === 'save') form.patch(url, visit)
    else if (commit === 'discard') form.delete(url, visit)
    else form.post(url, visit)
  }

  useShortcut('mod+s', () => save('save'), { when: () => !form.processing, label: 'Save' })
  useShortcut('mod+enter', () => save('publish'), {
    when: () =>
      !form.processing && ((page.props.can as { publish?: boolean } | undefined)?.publish ?? options.canPublish),
    label: 'Publish',
  })
  useDirtyGuard(() => form.isDirty, backup.clear)

  return { form, values, meta, draft, save, submitted, backup }
}
