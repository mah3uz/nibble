// Mirrors Nibble::Cp::Listing#props (Ruby).
export type ListingColumnType = 'text' | 'title' | 'status' | 'date' | 'list' | 'code' | 'number' | 'image'

export type ListingColumn = {
  handle: string
  label: string
  sortable: boolean
  visible: boolean
  default: boolean
  type: ListingColumnType
}

export type ListingFilter = {
  handle: string
  label: string
  type: 'select' | 'multi_select' | 'boolean'
  options: { value: string; label: string }[]
  value: string | string[] | null
}

export type ListingActionField = {
  handle: string
  type: string
  label: string
  options?: { value: string; label: string }[]
  [key: string]: unknown
}

export type ListingAction = {
  handle: string
  label: string
  confirm: string | null
  dangerous: boolean
  bulk: boolean
  fields: ListingActionField[]
}

export type ListingCellValue = string | number | string[] | null | { text: string; subtitle?: string | null }

export type ListingRow = Record<string, ListingCellValue> & { id: number; actions: string[]; edit_url: string | null }

export type ListingPreset = {
  handle: string
  label: string
  query: Record<string, string | string[]>
  built_in: boolean
}

export type ListingProps = {
  handle: string
  preference_key: string
  label: string
  rows: ListingRow[]
  columns: ListingColumn[]
  filters: ListingFilter[]
  search: { enabled: boolean; placeholder: string; value: string }
  sort: { column: string | null; direction: 'asc' | 'desc'; disabled_reason: string | null }
  pagination: { page: number; per_page: number; total: number; pages: number; per_page_options: number[] }
  actions: ListingAction[]
  presets: ListingPreset[]
  create: { label: string; url: string } | null
}
