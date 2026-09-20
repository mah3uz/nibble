export type { PublishBlueprint, PublishField, PublishSection, PublishTab } from '@nibble-admin/fieldtypes/types'

export type RecordStatus = 'draft' | 'in_review' | 'approved' | 'scheduled' | 'published' | 'unpublished'

export type EditMeta = {
  id: number | null
  status: RecordStatus
  live: boolean
  lock_version: number
  permalink: string | null
  updated_at: string | null
  updated_by: string | null
  workflow: 'simple' | 'review'
  workflow_status: RecordStatus | null
}

export type DraftMeta = { updated_at: string; user: string | null; stale: boolean } | null

export type Can = { edit: boolean; publish: boolean; delete: boolean; review: boolean }

export type EditUrls = {
  update: string
  publish: string | null
  unpublish: string | null
  submit: string | null
  approve: string | null
  reject: string | null
  discard: string | null
  trash: string | null
  preview: string | null
  versions: string | null
  comments: string | null
  listing: string
  create_another: string | null
}
