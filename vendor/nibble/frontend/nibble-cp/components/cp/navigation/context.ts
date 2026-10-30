import { inject, provide, type InjectionKey, type Ref } from 'vue'
import type { Path } from './tree'
import type { NavAsset, NavEntry, NavItemErrors, NavMenu, NavTreeItem } from './types'

export type NavEditor = {
  menu: NavMenu
  entries: NavEntry[]
  queryRecords: NavEntry[]
  tree: Ref<NavTreeItem[]>
  assets: Ref<Record<string, NavAsset>>
  errors: Ref<Record<string, NavItemErrors>>
  collapsed: Ref<Set<string>>
  change: (next: NavTreeItem[] | null, id: string, done: string) => void
  moveTo: (from: Path, toParent: Path, index: number) => void
}

const KEY: InjectionKey<NavEditor> = Symbol('nibble-nav-editor')

export const provideNavEditor = (editor: NavEditor) => provide(KEY, editor)

export function useNavEditor(): NavEditor {
  const editor = inject(KEY, null)
  if (!editor) throw new Error('Navigation components must be rendered inside the navigation editor')
  return editor
}
