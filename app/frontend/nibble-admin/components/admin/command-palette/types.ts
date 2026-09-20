export type PaletteItem = {
  title: string
  subtitle: string | null
  url: string
  icon: string
  status?: 'draft' | 'scheduled' | 'published'
}
export type PaletteGroup = { label: string; items: PaletteItem[] }
