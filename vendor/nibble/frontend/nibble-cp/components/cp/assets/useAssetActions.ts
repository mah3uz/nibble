import { toast } from 'vue-sonner'
import { useConfirm } from '@/lib/confirm'
import { request, RequestError, type AssetRow, type AssetUsage } from './api'
import type { AssetMenuAction } from './assetMenu'
import { directUpload } from './useUploads'

type Target = Pick<AssetRow, 'id' | 'filename' | 'url' | 'folder'>

export function useAssetActions(options: {
  folderOptions: () => { value: string; label: string }[]
  changed: () => void
  edit: (id: number) => void
  deleted?: (id: number) => void
  pickReplacement?: () => Promise<AssetRow | null>
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

  function pickFile(): Promise<File | null> {
    return new Promise((resolve) => {
      const input = document.createElement('input')
      input.type = 'file'
      input.addEventListener('change', () => resolve(input.files?.[0] ?? null))
      input.click()
    })
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
      case 'replace': {
        const replacement = await options.pickReplacement?.()
        if (!replacement || replacement.id === asset.id) return
        const result = await confirm({
          title: `Replace ${asset.filename}`,
          description: `Everything that uses ${asset.filename} will use ${replacement.filename} instead.`,
          confirmText: 'Replace',
          fields: [
            {
              handle: 'original',
              label: 'Then',
              options: [
                { value: 'keep', label: `Keep ${asset.filename}` },
                { value: 'delete', label: `Move ${asset.filename} to the trash` },
              ],
            },
          ],
        })
        if (!result) return
        const deleteOriginal = result.original === 'delete'
        return attempt(async () => {
          await request('POST', `/cp/media/${asset.id}/replace`, {
            with: replacement.id,
            delete_original: deleteOriginal,
          })
          if (deleteOriginal) options.deleted?.(asset.id)
        }, 'Replaced')
      }
      case 'reupload': {
        const file = await pickFile()
        if (!file) return
        return attempt(async () => {
          const signedId = await directUpload(file, () => {})
          await request('POST', `/cp/media/${asset.id}/reupload`, { signed_id: signedId })
        }, 'File replaced')
      }
      case 'delete':
        return destroy(asset)
    }
  }

  return { run }
}
