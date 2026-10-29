export type Link = { type: string; id?: number; title: string; url: string; children: Link[] }

export type SiteProps = {
  locale: string
  url: string
  params: Record<string, string>
  globals: Record<string, Record<string, unknown>>
  navigation: Record<string, Link[]>
}

export type RecordSummary = { id: string; type: string; title: string; uri: string | null; url: string | null }

export type SetBlock = { id: string; type: string; queries?: Record<string, unknown> } & Record<string, unknown>

export type RichTextValue = string | null | Array<{ type: 'text'; text: string } | SetBlock>

export type ImageValue = {
  url: string
  alt?: string | null
  width?: number | null
  height?: number | null
  srcset?: string | null
  focal?: { x: number; y: number } | null
}

export type PaginationMeta = { current_page: number; per_page: number; total: number; last_page: number }

export type SeoProps = {
  title: string
  description?: string | null
  canonical?: string | null
  robots?: string | null
  image?: string | null
}

export type NibbleFormConditionOperator =
  | 'equals' | 'not' | 'contains' | 'contains_any' | '===' | '!==' | '>' | '>=' | '<' | '<=' | 'custom'

export type NibbleFormConditions = {
  show: boolean
  match: 'all' | 'any'
  rules: { field: string | null; operator: NibbleFormConditionOperator; value: string }[]
}

export type NibbleFormField = {
  handle: string
  type: string
  display: string
  instructions: string | null
  required: boolean
  placeholder?: string
  input_type?: string
  character_limit?: number
  default?: unknown
  width?: number
  multiple?: boolean
  inline?: boolean
  options?: { value: string; label: string }[]
  max_files?: number
  max_file_size?: number
  extensions?: string[]
  prepend?: string
  append?: string
  min?: number
  max?: number
  step?: number
  autocomplete?: string
  rows?: number
  inline_label?: string
  time_enabled?: boolean
  earliest_date?: string
  latest_date?: string
  max_items?: number
  clearable?: boolean
  conditions?: NibbleFormConditions
  hidden?: boolean
  value?: string | number | boolean
}

export type NibbleFormSection = {
  display: string | null
  instructions: string | null
  fields: string[]
}

export type NibbleFormResult = {
  handle: string
  status: 'sent' | 'invalid'
  message?: string | null
  errors?: Record<string, string>
  values?: Record<string, string | number | boolean | (string | number)[]>
}

export type NibbleForm = {
  handle: string
  title: string | null
  action: string
  honeypot: string | null
  captcha: { provider: 'turnstile' | 'recaptcha' | null; site_key: string | null } | null
  fields: NibbleFormField[]
  sections: NibbleFormSection[] | null
  success: { message?: string; redirect?: string }
  result: NibbleFormResult | null
}
