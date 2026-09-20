declare module '@rails/activestorage' {
  export class DirectUpload {
    constructor(
      file: File,
      url: string,
      delegate?: { directUploadWillStoreFileWithXHR?: (xhr: XMLHttpRequest) => void },
    )
    create(callback: (error: Error | string | null, blob: { signed_id: string }) => void): void
  }
}
