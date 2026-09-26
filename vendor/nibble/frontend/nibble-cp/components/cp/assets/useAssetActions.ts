import { toast } from 'vue-sonner'
import { useConfirm } from '@/lib/confirm'
import { request, RequestError, type AssetRow, type AssetUsage } from './api'
import type { AssetMenuAction } from './assetMenu'
import { directUpload } from './useUploads'

type Target = Pick<AssetRow, 'id' | 'filename' | 'url' | 'folder' | 'kind'>

// A reupload has to stay the same kind of file, so the picker offers only those.
const ACCEPT: Record<string, string> = { image: 'image/*', svg: 'image/*', video: 'video/*', audio: 'audio/*' }

const extensionOf = (filename: string) => filename.split('.').pop()?.toLowerCase() ?? ''

export function useAssetActions(options: {
  folderOptions: () => { value: string; label: string }[]
  changed: () => void
  edit: (id: number) => void
  deleted?: (id: number) => void
  pickReplacement?: (title: string) => Promise<AssetRow | null>
}) {
  const confirm = useConfirm()

  async function attempt(work: () => Promise<unknown>, success: string) {
    try {
      await work()
      toast.success(success)
      options.changed()
    } catch (error) {
      toast.error((error as Error).message)
    }
  }

  function pickFile(accept = ''): Promise<File | null> {
    return new Promise((resolve) => {
      const input = Object.assign(document.createElement('input'), { type: 'file', accept })
      input.addEventListener('change', () => resolve(input.files?.[0] ?? null))
      input.addEventListener('cancel', () => resolve(null))
      input.click()
    })
  }

  async function reupload(asset: Target) {
    const file = await pickFile(ACCEPT[asset.kind])
    if (!file) return
    const from = extensionOf(asset.filename)
    const to = extensionOf(file.name)
    const renamed = to && to !== from ? ` Its name will end in .${to} instead of .${from}.` : ''
    const ok = await confirm({
      title: `Reupload ${asset.filename}?`,
      description: `${file.name} takes its place everywhere it's used.${renamed} The current file is deleted and can't be brought back.`,
      confirmText: 'Reupload',
      dangerous: true,
    })
    if (!ok) return
    const progress = toast.loading(`Uploading ${file.name}…`)
    try {
      const signedId = await directUpload(file, (percent) =>
        toast.loading(`Uploading ${file.name}… ${percent}%`, { id: progress }),
      )
      await request('POST', `/cp/media/${asset.id}/reupload`, { signed_id: signedId })
      toast.success('File replaced', { id: progress })
      options.changed()
    } catch (error) {
      toast.error((error as Error).message, { id: progress })
    }
  }

  async function replace(asset: Target) {
    const replacement = await options.pickReplacement?.(`Choose what replaces ${asset.filename}`)
    if (!replacement) return
    if (replacement.id === asset.id) return toast.error(`That's ${asset.filename} itself. Choose a different asset.`)
    const result = await confirm({
      title: `Replace ${asset.filename}`,
      description: `Everything that uses ${asset.filename} will use ${replacement.filename} instead.`,
      confirmText: 'Replace',
      fields: [
        {
          handle: 'original',
          label: 'Afterwards',
          options: [
            { value: 'keep', label: `Keep ${asset.filename}` },
            { value: 'delete', label: `Move ${asset.filename} to the trash` },
          ],
        },
      ],
    })
    if (!result) return
    const deleteOriginal = result.original === 'delete'
    try {
      const { replaced } = await request<{ replaced: number }>('POST', `/cp/media/${asset.id}/replace`, {
        with: replacement.id,
        delete_original: deleteOriginal,
      })
      const done = replaced
        ? `Replaced in ${replaced} ${replaced === 1 ? 'place' : 'places'}`
        : `Nothing used ${asset.filename}, so nothing changed`
      toast.success(deleteOriginal ? `${done}. ${asset.filename} is in the trash.` : `${done}.`)
      if (deleteOriginal) options.deleted?.(asset.id)
      options.changed()
    } catch (error) {
      toast.error((error as Error).message)
    }
  }

  async function destroy(asset: Target) {
    const ok = await confirm({
      title: `Delete ${asset.filename}?`,
      description: 'It moves to the trash.',
      confirmText: 'Delete',
      dangerous: true,
    })
    if (!ok) return
    try {
      await request('DELETE', `/cp/media/${asset.id}`)
    } catch (error) {
      if (!(error instanceof RequestError) || error.status !== 409) return toast.error((error as Error).message)
      const usage = (error.body.referrers as AssetUsage[]).map((item) => item.title).join(', ')
      const force = await confirm({
        title: `${asset.filename} is in use`,
        description: `It's used in ${usage}. Deleting it leaves those without it.`,
        confirmText: 'Delete anyway',
        dangerous: true,
      })
      if (!force) return
      await request('DELETE', `/cp/media/${asset.id}?force=true`)
    }
    toast.success('Moved to the trash')
    options.deleted?.(asset.id)
    options.changed()
  }

  async function run(action: AssetMenuAction, asset: Target) {
    switch (action) {
      case 'edit':
        return options.edit(asset.id)
      case 'copy':
        await navigator.clipboard.writeText(new URL(asset.url, window.location.origin).toString())
        return toast.success('URL copied')
      case 'download': {
        const link = Object.assign(document.createElement('a'), { href: asset.url, download: asset.filename })
        return link.click()
      }
      case 'duplicate':
        return attempt(() => request('POST', `/cp/media/${asset.id}/duplicate`), 'Duplicated')
      case 'move': {
        const result = await confirm({
          title: `Move ${asset.filename}`,
          confirmText: 'Move',
          fields: [
            { handle: 'folder', label: 'Folder', options: options.folderOptions(), value: asset.folder || 'root' },
          ],
        })
        if (!result) return
        const folder = result.folder === 'root' ? '' : result.folder
        return attempt(() => request('PATCH', `/cp/media/${asset.id}`, { asset: { folder } }), 'Moved')
      }
      case 'rename': {
        const result = await confirm({
          title: 'Rename',
          confirmText: 'Rename',
          fields: [
            { handle: 'filename', label: 'Filename', options: [], value: asset.filename.replace(/\.[^.]+$/, '') },
          ],
        })
        if (!result) return
        return attempt(
          () => request('PATCH', `/cp/media/${asset.id}`, { asset: { filename: result.filename } }),
          'Renamed',
        )
      }
      case 'replace':
        return replace(asset)
      case 'reupload':
        return reupload(asset)
      case 'delete':
        return destroy(asset)
    }
  }

  return { run }
}
