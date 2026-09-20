export type Width = 25 | 33 | 50 | 66 | 75 | 100
export type Visibility = 'visible' | 'read_only' | 'hidden' | 'computed'

// One field as sent by Nibble::Field#to_publish_h.
export type PublishField = {
  handle: string
  prefix: string | null
  type: string
  component: string
  display: string
  instructions: string | null
  instructions_position: 'above' | 'below'
  width: Width
  required: boolean
  visibility: Visibility
  read_only: boolean
  always_save: boolean
  localizable: boolean
  hide_display: boolean
  replicator_preview: boolean
  actions: boolean
  config: Record<string, unknown>
  [condition: string]: unknown
}

export type PublishSection = {
  display: string | null
  instructions: string | null
  collapsible: boolean
  collapsed: boolean
  fields: PublishField[]
}

export type PublishSet = {
  handle: string
  display: string
  instructions: string | null
  icon: string | null
  fields: PublishField[]
}
export type PublishSetGroup = {
  handle: string
  display: string | null
  instructions: string | null
  icon: string | null
  sets: PublishSet[]
}

export type PublishTab = { handle: string; display: string; sections: PublishSection[] }

export type PublishBlueprint = { handle: string; title: string; tabs: PublishTab[] }

// What a fieldtype component receives as `config`: the field's common options merged with its fieldtype options.
export type FieldConfig = Omit<PublishField, 'config'> & Record<string, unknown>

export function fieldConfig(field: PublishField): FieldConfig {
  const { config, ...common } = field
  return { ...config, ...common }
}
