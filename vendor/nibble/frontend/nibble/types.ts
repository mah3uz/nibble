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
  'equals' | 'not' | 'contains' | 'contains_any' | '===' | '!==' | '>' | '>=' | '<' | '<=' | 'custom'

export type NibbleFormConditions = {
  show: boolean
  match: 'all' | 'any'
  rules: { field: string | null; operator: NibbleFormConditionOperator; value: string }[]
}

type NibbleFormOption = { value: string; label: string }

type NibbleFormFieldBase = {
  handle: string
  display: string
  instructions: string | null
  required: boolean | NibbleFormConditions
  default?: unknown
  width?: number
  conditions?: NibbleFormConditions
  hidden?: boolean
  value?: string | number | boolean
}

type NibbleFormFieldTypes = {
  text: {
    placeholder?: string
    input_type?: string
    character_limit?: number
    autocomplete?: string
    prepend?: string
    append?: string
  }
  textarea: { placeholder?: string; character_limit?: number; rows?: number }
  integer: { placeholder?: string; min?: number; max?: number; step?: number; prepend?: string; append?: string }
  decimal: {
    placeholder?: string
    decimals?: number
    min?: number
    max?: number
    step?: number
    prepend?: string
    append?: string
  }
  range: { min?: number; max?: number; step?: number; prepend?: string; append?: string }
  rating: { max?: number }
  toggle: { inline_label?: string; inline_label_html?: string }
  select: {
    placeholder?: string
    options: NibbleFormOption[]
    multiple?: boolean
    max_items?: number
    clearable?: boolean
  }
  radio: { options: NibbleFormOption[]; inline?: boolean }
  checkboxes: { options: NibbleFormOption[]; inline?: boolean }
  date: { inline?: boolean; time_enabled?: boolean; earliest_date?: string; latest_date?: string }
  files: { max_files?: number; max_file_size?: number; extensions?: string[] }
  calculation: { formula: string; decimals?: number; prepend?: string; append?: string }
  note: { text_html?: string }
}

type NibbleFormFieldKey = {
  [T in keyof NibbleFormFieldTypes]: keyof NibbleFormFieldTypes[T]
}[keyof NibbleFormFieldTypes]

export type NibbleFormFieldType = keyof NibbleFormFieldTypes

// Every member lists the others' settings as undefined, so a theme can read one before narrowing on `type`.
export type NibbleFormField = {
  [T in NibbleFormFieldType]: NibbleFormFieldBase & { type: T } & NibbleFormFieldTypes[T] & {
      [K in Exclude<NibbleFormFieldKey, keyof NibbleFormFieldTypes[T]>]?: undefined
    }
}[NibbleFormFieldType]

export type NibbleFormValue = string | number | boolean | (string | number)[] | File[] | null

export type NibbleFormSection = {
  display: string | null
  instructions: string | null
  fields: string[]
}

export type NibbleFormResult = {
  handle: string
  status: 'sent' | 'invalid' | 'resumed' | 'expired'
  message?: string | null
  errors?: Record<string, string>
  values?: Record<string, string | number | boolean | (string | number)[]>
}

export type NibbleFormMessageKey =
  | 'choose'
  | 'send'
  | 'sending'
  | 'next'
  | 'checking'
  | 'back'
  | 'save_later'
  | 'step'
  | 'check_answers'
  | 'required_note'
  | 'required'

export type NibbleForm<Values extends Record<string, unknown> = Record<string, NibbleFormValue>> = {
  readonly __values?: Values
  handle: string
  title: string | null
  action: string
  honeypot: string | null
  captcha: { provider: 'turnstile' | 'recaptcha' | null; site_key: string | null } | null
  fields: NibbleFormField[]
  sections: NibbleFormSection[] | null
  steps?: boolean
  resume?: { email: string; days: number; token: string | null } | null
  success: { message?: string; redirect?: string }
  messages?: { too_large: string; generic: string; network: string } & Partial<Record<NibbleFormMessageKey, string>>
  submit_label?: string | null
  closed?: boolean
  closed_message?: string | null
  timestamp?: string | null
  result: NibbleFormResult | null
}
