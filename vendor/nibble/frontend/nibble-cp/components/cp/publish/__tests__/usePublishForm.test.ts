import { effectScope, reactive } from 'vue'
import { beforeEach, describe, expect, it, vi } from 'vitest'
import type { EditMeta, EditUrls } from '../context'

type Visit = { onSuccess?: () => void; onFinish?: () => void }
type Request = { method: string; url: string; body: Record<string, unknown> }

const requests: Request[] = []
const page = reactive<{ props: Record<string, unknown> }>({ props: {} })
let respond: (request: Request) => boolean = () => true

vi.mock('@inertiajs/vue3', async () => {
  const { reactive } = await import('vue')
  return {
    router: { visit: vi.fn() },
    usePage: () => page,
    useForm: (initial: Record<string, unknown>) => {
      let transform = (data: Record<string, unknown>) => data
      const send = (method: string) => (url: string, visit: Visit) => {
        const data = Object.fromEntries(Object.entries(form).filter(([key]) => key in initial))
        const request = { method, url, body: transform(data) }
        requests.push(request)
        if (respond(request)) visit.onSuccess?.()
        visit.onFinish?.()
      }
      const form = reactive({
        ...initial,
        isDirty: true,
        processing: false,
        errors: {},
        transform: (fn: typeof transform) => (transform = fn),
        defaults: () => {},
        post: send('post'),
        patch: send('patch'),
        delete: send('delete'),
      })
      return form
    },
  }
})
vi.mock('@/lib/cp', async () => {
  const { ref } = await import('vue')
  return { useCp: () => ref({ user: { id: 1 } }) }
})
vi.mock('@/lib/dirty-guard', () => ({ skipNextGuard: () => {}, useDirtyGuard: () => {} }))
vi.mock('@/lib/local-backup', () => ({ useLocalBackup: () => ({ clear: () => {}, available: { value: null } }) }))
vi.mock('@/lib/preferences', async () => {
  const { ref } = await import('vue')
  return { usePreference: (_key: string, fallback: unknown) => ref(fallback) }
})
vi.mock('@/lib/shortcuts', () => ({ useShortcut: () => {} }))

const base = '/cp/collections/pages/entries'
const blank = {
  update: base,
  publish: null,
  unpublish: null,
  submit: null,
  approve: null,
  reject: null,
  discard: null,
  trash: null,
  preview: null,
  versions: null,
  comments: null,
  listing: '/cp/collections/pages',
  create_another: null,
} as unknown as EditUrls
const member = { ...blank, update: `${base}/7`, publish: `${base}/7/publish`, discard: `${base}/7/draft` } as EditUrls
const meta = (id: number | null, lock_version: number) =>
  ({
    id,
    status: 'draft',
    live: false,
    lock_version,
    permalink: null,
    updated_at: null,
    updated_by: null,
    workflow: 'simple',
    workflow_status: null,
  }) as unknown as EditMeta

beforeEach(() => {
  requests.length = 0
  page.props = {}
  respond = ({ method, url }) => {
    if (method === 'post' && url === base) page.props = { urls: member, meta: meta(7, 1), draft: null }
    return true
  }
})

async function newEntry() {
  const { usePublishForm } = await import('../usePublishForm')
  let form!: ReturnType<typeof usePublishForm>
  effectScope().run(() => {
    form = usePublishForm({
      resourceKey: 'entry',
      urls: blank,
      values: { title: 'Hello', lock_version: 0 },
      meta: meta(null, 0),
      draft: null,
      canPublish: true,
    })
  })
  return form
}

describe('usePublishForm on a new entry', () => {
  it('publishes in one click: Publish creates the entry and then publishes it, instead of doing nothing until a draft is saved', async () => {
    const { save } = await newEntry()

    save('publish')

    expect(requests.map(({ method, url }) => [method, url])).toEqual([
      ['post', base],
      ['post', `${base}/7/publish`],
    ])
    expect(requests[1].body).toEqual({ entry: { title: 'Hello', lock_version: 1 } })
  })

  it('stops after creating when the entry is invalid, so nothing is published that was not saved', async () => {
    respond = () => false
    const { save } = await newEntry()

    save('publish')

    expect(requests.map(({ url }) => url)).toEqual([base])
  })

  it('saves a draft with one request and goes no further', async () => {
    const { save } = await newEntry()

    save('save')

    expect(requests.map(({ method, url }) => [method, url])).toEqual([['post', base]])
  })
})
