<script setup lang="ts">
import { router } from '@inertiajs/vue3'
import { ref } from 'vue'
import AdminPanel from '@/components/admin/page/AdminPanel.vue'
import PageHeader from '@/components/admin/page/PageHeader.vue'
import { Button } from '@/components/ui/button'
import { useBreadcrumbs } from '@/lib/breadcrumbs'
import { useConfirm } from '@/lib/confirm'

type Queue = { name: string; ready: number; oldest_at: string | null }
type Running = { id: number; job: string; queue: string; started_at: string; process: string | null }
type Upcoming = { id: number; job: string; queue: string; at: string }
type Failed = {
  id: number
  job_id: number
  job: string
  queue: string
  exception: string
  message: string
  backtrace: string[]
  failed_at: string
}
type Recurring = { key: string; schedule: string; job: string; queue: string; last_run_at: string | null }

defineProps<{
  jobs:
    | { available: false }
    | {
        available: true
        queues: Queue[]
        in_progress: Running[]
        scheduled: { count: number; upcoming: Upcoming[] }
        failed: Failed[]
        recurring: Recurring[]
      }
}>()

const confirm = useConfirm()
const expanded = ref<number | null>(null)

const date = (value: string) => new Date(value).toLocaleString(undefined, { dateStyle: 'medium', timeStyle: 'short' })

const retry = (job: Failed) => router.post(`/admin/utilities/jobs/${job.id}/retry`, {}, { preserveScroll: true })

async function discard(job: Failed) {
  const ok = await confirm({
    title: `Discard ${job.job}?`,
    description: 'It won’t run again, and its error is removed from this list.',
    confirmText: 'Discard',
    dangerous: true,
  })
  if (ok) router.delete(`/admin/utilities/jobs/${job.id}`, { preserveScroll: true })
}

useBreadcrumbs([{ label: 'Utilities', url: '/admin/utilities' }, { label: 'Jobs' }])
</script>

<template>
  <div>
    <PageHeader
      title="Jobs"
      icon="jobs"
      :breadcrumbs="[{ label: 'Utilities', url: '/admin/utilities' }, { label: 'Jobs' }]"
    />

    <AdminPanel v-if="!jobs.available">
      <p class="text-sm text-gray-600 dark:text-gray-400">
        Jobs run inside the app in this environment, so there’s no queue to show. In production they run through Solid
        Queue, and this screen lists them.
      </p>
    </AdminPanel>

    <template v-else>
      <AdminPanel title="Queues">
        <div class="grid grid-cols-2 gap-3 sm:grid-cols-5">
          <div v-for="queue in jobs.queues" :key="queue.name" class="rounded-lg bg-gray-50 px-4 py-3 dark:bg-gray-900">
            <p class="text-xs text-gray-500">{{ queue.name }}</p>
            <p class="text-2xl font-medium tabular-nums">{{ queue.ready }}</p>
            <p class="text-xs text-gray-500">
              {{ queue.oldest_at ? `oldest ${date(queue.oldest_at)}` : 'nothing waiting' }}
            </p>
          </div>
        </div>
      </AdminPanel>

      <AdminPanel :title="`Failed (${jobs.failed.length})`" flush>
        <div class="text-sm">
          <p v-if="!jobs.failed.length" class="px-4.5 py-4 text-gray-500">Nothing has failed.</p>
          <div
            v-for="job in jobs.failed"
            :key="job.id"
            class="border-b border-gray-100 last:border-0 dark:border-gray-800"
          >
            <div class="flex items-center gap-3 px-4.5 py-3">
              <button
                type="button"
                class="flex min-w-0 flex-1 items-center gap-3 text-start"
                :aria-expanded="expanded === job.id"
                @click="expanded = expanded === job.id ? null : job.id"
              >
                <code class="shrink-0 text-xs">{{ job.job }}</code>
                <span class="flex-1 truncate text-gray-600 dark:text-gray-400"
                  >{{ job.exception }}: {{ job.message }}</span
                >
                <span class="shrink-0 text-xs text-gray-500">{{ job.queue }} · {{ date(job.failed_at) }}</span>
              </button>
              <Button size="sm" variant="outline" @click="retry(job)">Retry</Button>
              <Button size="sm" variant="outline" @click="discard(job)">Discard</Button>
            </div>
            <div v-if="expanded === job.id" class="border-t border-gray-100 px-4.5 py-3 dark:border-gray-800">
              <p class="mb-2 text-xs text-gray-500">Job #{{ job.job_id }}</p>
              <pre tabindex="0" class="max-h-72 overflow-auto rounded-lg bg-gray-50 p-3 text-xs dark:bg-gray-900">{{
                [`${job.exception}: ${job.message}`, ...job.backtrace].join('\n')
              }}</pre>
            </div>
          </div>
        </div>
      </AdminPanel>

      <AdminPanel title="Running now" flush>
        <div class="text-sm">
          <p v-if="!jobs.in_progress.length" class="px-4.5 py-4 text-gray-500">Nothing is running.</p>
          <div
            v-for="job in jobs.in_progress"
            :key="job.id"
            class="flex items-center gap-3 border-b border-gray-100 px-4.5 py-3 last:border-0 dark:border-gray-800"
          >
            <code class="text-xs">{{ job.job }}</code>
            <span class="flex-1 text-gray-600 dark:text-gray-400">{{ job.process ?? 'unknown worker' }}</span>
            <span class="text-xs text-gray-500">{{ job.queue }} · since {{ date(job.started_at) }}</span>
          </div>
        </div>
      </AdminPanel>

      <AdminPanel title="Schedule" :description="`${jobs.scheduled.count} waiting for their time`" flush>
        <div class="text-sm">
          <p v-if="!jobs.recurring.length" class="px-4.5 py-4 text-gray-500">
            No recurring jobs have been loaded yet; they appear once the scheduler has started.
          </p>
          <div
            v-for="task in jobs.recurring"
            :key="task.key"
            class="flex items-center gap-3 border-b border-gray-100 px-4.5 py-3 last:border-0 dark:border-gray-800"
          >
            <code class="text-xs">{{ task.job }}</code>
            <span class="flex-1 text-gray-600 dark:text-gray-400">{{ task.schedule }}</span>
            <span class="text-xs text-gray-500">
              {{ task.queue }} · {{ task.last_run_at ? `last ran ${date(task.last_run_at)}` : 'not run yet' }}
            </span>
          </div>
        </div>
      </AdminPanel>
    </template>
  </div>
</template>
