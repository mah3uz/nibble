import type { Abilities } from './api'

export type AssetMenuAction =
  'edit' | 'copy' | 'download' | 'duplicate' | 'move' | 'rename' | 'replace' | 'reupload' | 'delete'

export type AssetMenuItem = {
  action: AssetMenuAction
  label: string
  icon: string
  destructive?: boolean
  separated?: boolean
}

export function assetMenuItems(can: Abilities): AssetMenuItem[] {
  const items: (AssetMenuItem & { allowed: boolean })[] = [
    { action: 'edit', label: 'Edit', icon: 'edit', allowed: true },
    { action: 'copy', label: 'Copy URL', icon: 'clipboard', allowed: true, separated: true },
    { action: 'download', label: 'Download', icon: 'download', allowed: true },
    { action: 'duplicate', label: 'Duplicate', icon: 'duplicate', allowed: can.upload },
    { action: 'move', label: 'Move', icon: 'move-folder', allowed: can.edit },
    { action: 'rename', label: 'Rename', icon: 'rename', allowed: can.edit },
    { action: 'replace', label: 'Replace', icon: 'replace', allowed: can.edit },
    { action: 'reupload', label: 'Reupload', icon: 'upload-cloud', allowed: can.edit },
    { action: 'delete', label: 'Delete', icon: 'trash', allowed: can.delete, destructive: true },
  ]
  return items.filter((item) => item.allowed)
}
