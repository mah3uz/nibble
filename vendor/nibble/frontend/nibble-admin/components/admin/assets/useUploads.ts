import { ref } from 'vue'
import { request, type AssetRow } from './api'

export type UploadRow = {
  id: string
  name: string
  progress: number
  status: 'uploading' | 'done' | 'error'
  error?: string
}

// @rails/activestorage touches window on import, which crashes SSR, so it loads on first upload.
export async function directUpload(file: File, onProgress: (percent: number) => void): Promise<string> {
  const { DirectUpload } = await import('@rails/activestorage')
  return new Promise((resolve, reject) => {
    const upload = new DirectUpload(file, '/admin/direct_uploads', {
      directUploadWillStoreFileWithXHR: (xhr) =>
        xhr.upload.addEventListener('progress', (event) => onProgress(Math.round((event.loaded / event.total) * 100))),
    })
    upload.create((error, blob) => (error ? reject(new Error(uploadError(error))) : resolve(blob.signed_id)))
  })
}

function uploadError(error: Error | string) {
  const message = typeof error === 'string' ? error : error.message
  const detail = message.match(/"error":"([^"]+)"/)?.[1]
  return detail ?? message.replace(/^Error creating Blob for ".*"\. /, '')
}

export function useUploads(folder: () => string, onUploaded: (asset: AssetRow) => void) {
  const rows = ref<UploadRow[]>([])

  function patch(id: string, changes: Partial<UploadRow>) {
    const row = rows.value.find((r) => r.id === id)
    if (row) Object.assign(row, changes)
  }

  async function uploadOne(file: File) {
    const id = `${Date.now()}-${Math.random().toString(36).slice(2)}`
    rows.value = [...rows.value, { id, name: file.name, progress: 0, status: 'uploading' }]
    try {
      const signedId = await directUpload(file, (progress) => patch(id, { progress }))
      const { asset } = await request<{ asset: AssetRow }>('POST', '/admin/media', {
        signed_id: signedId,
        folder: folder(),
      })
      patch(id, { status: 'done', progress: 100 })
      onUploaded(asset)
      setTimeout(() => (rows.value = rows.value.filter((r) => r.id !== id)), 1500)
    } catch (error) {
      patch(id, { status: 'error', error: (error as Error).message })
    }
  }

  function upload(files: FileList | File[]) {
    return Promise.all(Array.from(files).map(uploadOne))
  }

  function dismiss(id: string) {
    rows.value = rows.value.filter((r) => r.id !== id)
  }

  return { rows, upload, dismiss }
}
