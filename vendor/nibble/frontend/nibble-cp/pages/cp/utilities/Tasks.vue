<script setup lang="ts">
import { router } from '@inertiajs/vue3'
import { CalendarClock, CircleAlert, Info } from '@lucide/vue'
import { computed, ref } from 'vue'
import ExternalLinkIcon from '@/components/cp/icons/ExternalLinkIcon.vue'
import StatusCell from '@/components/cp/listing/cells/StatusCell.vue'
import CpPanel from '@/components/cp/page/CpPanel.vue'
import EmptyState from '@/components/cp/page/EmptyState.vue'
import PageHeader from '@/components/cp/page/PageHeader.vue'
import TaskHistory, { type Run } from '@/components/cp/tasks/TaskHistory.vue'
import { Button } from '@/components/ui/button'
import { useBreadcrumbs } from '@/lib/breadcrumbs'
import { timeAgo } from '@/lib/format'

type Task = {
  handle: string
  title: string
  description: string | null
  schedule: string
  paused: boolean
  running: boolean
  failing_since: string | null
  next_run_at: string | null
  last_run: Run | null
}

const props = defineProps<{ tasks: Task[]; scheduler: boolean; time_zone: string }>()

const DOCS = 'https://nibble.ink/docs/modelling/scheduled-tasks'

const history = ref<Task | null>(null)

const when = (iso: string) =>
  new Date(iso).toLocaleString('en-AU', {
    timeZone: props.time_zone,
    weekday: 'short',
    day: 'numeric',
    month: 'short',
    hour: 'numeric',
    minute: '2-digit',
  })

const zoneName = computed(() => props.time_zone.replace(/^Etc\//, '').replaceAll('_', ' '))

const lastRanAt = (run: Run) => run.finished_at ?? run.started_at ?? run.scheduled_for

const post = (task: Task, action: 'run' | 'pause' | 'resume') =>
  router.post(`/cp/utilities/tasks/${task.handle}/${action}`, {}, { preserveScroll: true })

useBreadcrumbs([{ label: 'Utilities', url: '/cp/utilities' }, { label: 'Scheduled tasks' }])
</script>

<template>
  <div>
    <PageHeader
      title="Scheduled tasks"
      icon="calendar"
      :breadcrumbs="[{ label: 'Utilities', url: '/cp/utilities' }, { label: 'Scheduled tasks' }]"
    />

    <p
      v-if="!scheduler"
      class="mb-6 flex items-start gap-2 rounded-lg bg-gray-100 px-3.5 py-2.5 text-sm text-gray-700 dark:bg-gray-850 dark:text-gray-300"
    >
      <Info class="mt-0.5 size-4 shrink-0 text-gray-500" />
      <span>
        No job scheduler runs in this environment, so tasks don’t start on their schedule here.
        <strong class="font-medium">Run now</strong> still runs one.
      </span>
    </p>

    <CpPanel v-if="!tasks.length">
      <EmptyState :icon="CalendarClock" title="No scheduled tasks">
        <p class="max-w-md text-sm text-muted-foreground">
          Tasks are declared in <code class="text-xs">site/schema/tasks/</code>, one file each, and appear here with
          their runs.
        </p>
        <Button as-child variant="outline" size="sm">
          <a :href="DOCS" target="_blank" rel="noopener">How to declare a task <ExternalLinkIcon class="size-3" /></a>
        </Button>
      </EmptyState>
    </CpPanel>

    <CpPanel v-else title="Tasks" :description="`Times are in ${zoneName}.`" flush>
      <ul class="text-sm" role="list">
        <li
          v-for="task in tasks"
          :key="task.handle"
          class="border-b border-gray-100 px-4.5 py-4 last:border-0 dark:border-gray-800"
        >
          <div class="flex flex-wrap items-start gap-x-4 gap-y-3">
            <div class="min-w-0 flex-1 basis-64">
              <div class="flex flex-wrap items-center gap-2">
                <h3 class="font-medium text-gray-925 dark:text-white">{{ task.title }}</h3>
                <StatusCell v-if="task.running" value="running" />
                <StatusCell v-if="task.paused" value="paused" />
              </div>
              <p v-if="task.description" class="mt-0.5 text-gray-600 dark:text-gray-400">{{ task.description }}</p>
            </div>
            <div class="flex shrink-0 flex-wrap gap-2">
              <Button size="sm" variant="outline" @click="post(task, 'run')">Run now</Button>
              <Button v-if="task.paused" size="sm" variant="outline" @click="post(task, 'resume')">Resume</Button>
              <Button v-else size="sm" variant="outline" @click="post(task, 'pause')">Pause</Button>
              <Button size="sm" variant="ghost" @click="history = task">History</Button>
            </div>
          </div>

          <p
            v-if="task.failing_since"
            class="mt-3 flex items-center gap-1.5 text-red-700 dark:text-red-300"
            :title="when(task.failing_since)"
          >
            <CircleAlert class="size-4 shrink-0" />
            Failing since {{ when(task.failing_since) }}
          </p>

          <dl
            class="mt-3 grid grid-cols-2 gap-x-6 gap-y-3 sm:grid-cols-[minmax(0,10rem)_minmax(0,14rem)_minmax(0,1fr)]"
          >
            <div>
              <dt class="text-xs text-gray-500">Schedule</dt>
              <dd class="mt-0.5">{{ task.schedule }}</dd>
            </div>
            <div>
              <dt class="text-xs text-gray-500">Next run</dt>
              <dd v-if="task.paused" class="mt-0.5 text-gray-600 dark:text-gray-400">Paused</dd>
              <dd v-else-if="task.next_run_at" class="mt-0.5">
                <time :datetime="task.next_run_at" class="tabular-nums">{{ when(task.next_run_at) }}</time>
                <span class="block text-xs text-gray-500">{{ timeAgo(task.next_run_at) }}</span>
              </dd>
              <dd v-else class="mt-0.5 text-gray-600 dark:text-gray-400">Can’t read the schedule</dd>
            </div>
            <div class="col-span-2 min-w-0 sm:col-span-1">
              <dt class="text-xs text-gray-500">Last run</dt>
              <dd v-if="task.last_run" class="mt-0.5">
                <span class="flex flex-wrap items-center gap-2">
                  <StatusCell :value="task.last_run.status" />
                  <time :datetime="lastRanAt(task.last_run)" :title="when(lastRanAt(task.last_run))">{{
                    timeAgo(lastRanAt(task.last_run))
                  }}</time>
                </span>
                <span
                  v-if="task.last_run.message"
                  class="mt-0.5 block truncate text-xs text-gray-500"
                  :title="task.last_run.message"
                  >{{ task.last_run.message }}</span
                >
              </dd>
              <dd v-else class="mt-0.5 text-gray-600 dark:text-gray-400">Not run yet</dd>
            </div>
          </dl>
        </li>
      </ul>
    </CpPanel>

    <TaskHistory :task="history" :time-zone="time_zone" @close="history = null" />
  </div>
</template>
