export type WidgetLayoutItem = { type: string; width: 33 | 50 | 66 | 100; height?: string | null }
export type AvailableWidget = { type: string; label: string }

export type EntryStatus = 'draft' | 'in_review' | 'approved' | 'scheduled' | 'published' | 'unpublished'

export type RecentItem = {
  id: number
  title: string
  status: EntryStatus
  live: boolean
  path: string | null
  updated_at: string
  edit_url: string
}
export type RecentEntriesData = { items: RecentItem[]; create_url: string | null }

export type ScheduledItem = {
  type: string
  id: number
  title: string
  path: string | null
  published_at: string
  edit_url: string
}
export type ScheduledData = { items: ScheduledItem[] }

export type DraftItem = {
  type: string
  id: number
  title: string
  path: string | null
  updated_at: string
  user: string | null
  edit_url: string
}
export type DraftsData = { items: DraftItem[] }

export type ActivityItem = {
  item_type: string
  event: string
  verb: string
  after: string | null
  created_at: string
  author: string | null
  title: string | null
  url: string | null
}
export type ActivityData = { items: ActivityItem[] }

export type ContentHealthItem = { label: string; count: number; url: string }
export type ContentHealthData = { items: ContentHealthItem[] }

export type QuickLink = { label: string; url: string; icon: string; description: string }
export type QuickLinksData = { links: QuickLink[] }

export type OverviewTile = {
  key: string
  label: string
  url: string
  total: number
  series: number[]
}
export type OverviewData = { tiles: OverviewTile[] }

export type ActivityChartData = { start: string; series: { key: string; label: string; values: number[] }[] }

export type MixKey = 'published' | 'scheduled' | 'in_review' | 'draft' | 'unpublished'
export type ContentMixData = {
  collections: { handle: string; title: string; url: string; counts: Record<MixKey, number>; total: number }[]
}

export type ReviewItem = RecentItem & { user: string | null; since: string }
export type AwaitingReviewData = { items: ReviewItem[] }

export type SubmissionItem = {
  id: number
  form: string
  unread: boolean
  summary: string
  created_at: string
  url: string
}
export type FormSubmissionsData = { items: SubmissionItem[]; unread: number }

export type MissingPageItem = { path: string; hits: number; last_seen_at: string; redirect_url: string }
export type MissingPagesData = { items: MissingPageItem[] }

export type HealthCheck = { name: string; status: 'ok' | 'warn' | 'fail' | 'skip'; message: string; ms: number }
export type SiteHealthData = { status: 'ok' | 'degraded' | 'down'; url: string; checks: HealthCheck[] }

export type FailureItem = { title: string; detail: string; kind: string; at: string; url: string }
export type FailuresData = { items: FailureItem[] }

export type CommentItem = {
  id: number
  author: string | null
  body: string
  title: string
  resolved: boolean
  created_at: string
  url: string
}
export type CommentsData = { items: CommentItem[] }

export type UploadItem = {
  id: number
  title: string
  kind: string
  extension: string
  thumbnail: string | null
  created_at: string
  url: string
}
export type UploadsData = { items: UploadItem[] }
