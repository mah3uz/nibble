const GROUPS: Record<string, string[]> = {
  folder: ['folder'],
  archive: ['7z', 'pkg', 'rar', 'tar', 'gz', 'z', 'zip'],
  audio: ['aac', 'aif', 'cda', 'flac', 'm4a', 'mp3', 'mp4a', 'mpa', 'ogg', 'mid', 'midi', 'wav', 'wma'],
  doc: ['doc', 'docx', 'epub', 'mobi'],
  excel: ['xls', 'xlsx'],
  json: ['json'],
  layered: ['af', 'ai', 'eps', 'fig', 'indb', 'indd', 'psd', 'psb', 'sketch'],
  pdf: ['pdf'],
  presentation: ['key', 'odp', 'pps', 'ppt', 'pptx'],
  video: ['3g2', '3gp', 'avi', 'flv', 'h264', 'm4v', 'mvk', 'mp4', 'mpg', 'mpeg', 'mov', 'rm', 'swf', 'vob', 'wmv'],
  xml: ['xml'],
  image: [
    'avif',
    'bmp',
    'gif',
    'heic',
    'heif',
    'ico',
    'jpg',
    'jpeg',
    'png',
    'apng',
    'raw',
    'dng',
    'nef',
    'tif',
    'tiff',
    'webp',
  ],
}

export function fileIconName(extension: string) {
  const ext = extension.toLowerCase()
  return Object.entries(GROUPS).find(([, list]) => list.includes(ext))?.[0] ?? 'generic'
}
