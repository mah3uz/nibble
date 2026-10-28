<script setup lang="ts">
import { computed, ref, watch } from 'vue'
import { toast } from 'vue-sonner'
import StatusCell from '@/components/cp/listing/cells/StatusCell.vue'
import PanelFact from '@/components/cp/page/PanelFact.vue'
import { Sheet, SheetContent, SheetDescription, SheetHeader, SheetTitle } from '@/components/ui/sheet'
import { humanize } from '@/lib/utils'

export type Run = {
  id: number
  status: 'queued' | 'running' | 'succeeded' | 'failed' | 'skipped'
  manual: boolean
  scheduled_for: string
  started_at: string | null
  finished_at: string | null
  message: string | null
  details: Record<string, unknown>
}

const props = defineProps<{ task: { handle: string; title: string } | null; timeZone: string }>()
const emit = defineEmits<{ close: [] }>()

const runs = ref<Run[] | null>(null)
const limit = ref(0)

watch(
  () => props.task,
  async (task) => {
    runs.value = null
    if (!task) return
    const response = await fetch(`/cp/utilities/tasks/${task.handle}/runs`, { headers: { Accept: 'application/json' } })
    if (!response.ok) {
      toast.error(`Couldn't load the runs of ${task.title}.`)
      return
    }
    const payload = await response.json()
    runs.value = payload.runs
    limit.value = payload.limit
  },
  { immediate: true },
)

const groups = computed(() => {
  const byDay = new Map<string, Run[]>()
  for (const run of runs.value ?? []) {
    const day = new Date(run.started_at ?? run.scheduled_for).toLocaleDateString('en-AU', {
      timeZone: props.timeZone,
      weekday: 'long',
      day: 'numeric',
      month: 'long',
    })
    byDay.set(day, [...(byDay.get(day) ?? []), run])
  }
  return [...byDay.entries()].map(([day, list]) => ({ day, runs: list }))
})

const LABELS: Record<string, string> = {
  items: 'In the response',
  changed: 'Fields saved',
  missing: 'Not in the response',
  skipped_reasons: 'Why items were skipped',
  status: 'HTTP status',
}
const label = (key: string) => LABELS[key] ?? humanize(key)
const text = (value: unknown) => (typeof value === 'string' ? value : JSON.stringify(value))

function facts(details: Record<string, unknown>) {
  return Object.entries(details).filter(([, value]) => !Array.isArray(value) && value !== null && value !== '')
}

function lists(details: Record<string, unknown>) {
  return Object.entries(details).filter(
    (entry): entry is [string, unknown[]] => Array.isArray(entry[1]) && entry[1].length > 0,
  )
}

const time = (iso: string) =>
  new Date(iso).toLocaleTimeString('en-AU', { timeZone: props.timeZone, hour: 'numeric', minute: '2-digit' })

function took(run: Run) {
  if (!run.started_at || !run.finished_at) return null
  const seconds = (Date.parse(run.finished_at) - Date.parse(run.started_at)) / 1000
  return seconds < 60 ? `${seconds.toFixed(seconds < 10 ? 1 : 0)} s` : `${Math.round(seconds / 60)} min`
}
</script>

<template>
  <Sheet :open="!!task" @update:open="(open) => !open && emit('close')">
    <SheetContent size="narrow" class="gap-0">
      <SheetHeader>
        <SheetTitle>{{ task?.title }}</SheetTitle>
        <SheetDescription>Runs from the last 30 days, newest first.</SheetDescription>
      </SheetHeader>
      <div class="flex-1 space-y-5 overflow-y-auto p-6">
        <p v-if="!runs" class="text-sm text-muted-foreground">Loading…</p>
        <p v-else-if="!runs.length" class="text-sm text-muted-foreground">It hasn’t run yet.</p>
        <section v-for="group in groups" :key="group.day" class="space-y-2">
          <h3 class="text-xs font-medium tracking-wide text-muted-foreground uppercase">{{ group.day }}</h3>
          <article v-for="run in group.runs" :key="run.id" class="space-y-2 rounded-md border p-3 text-sm">
            <div class="flex flex-wrap items-center gap-x-2 gap-y-1">
              <StatusCell :value="run.status" />
              <time :datetime="run.started_at ?? run.scheduled_for" class="font-medium tabular-nums">{{
                time(run.started_at ?? run.scheduled_for)
              }}</time>
              <span class="text-muted-foreground">{{ run.manual ? 'Run now' : 'Scheduled' }}</span>
              <span v-if="took(run)" class="ms-auto text-xs text-muted-foreground tabular-nums"
                >took {{ took(run) }}</span
              >
            </div>
            <p v-if="run.message" class="break-words text-gray-700 dark:text-gray-300">{{ run.message }}</p>
            <div v-if="facts(run.details).length" class="flex flex-wrap gap-1.5">
              <PanelFact
                v-for="[key, value] in facts(run.details)"
                :key="key"
                :label="label(key)"
                :value="typeof value === 'number' ? value : text(value)"
              />
            </div>
            <div v-for="[key, items] in lists(run.details)" :key="key" class="space-y-1">
              <p class="text-xs font-medium text-gray-700 dark:text-gray-300">{{ label(key) }}</p>
              <ul
                class="space-y-0.5 text-xs break-words"
                :class="key === 'errors' ? 'text-red-700 dark:text-red-300' : 'text-gray-600 dark:text-gray-400'"
              >
                <li v-for="(item, index) in items" :key="index">{{ text(item) }}</li>
              </ul>
            </div>
          </article>
        </section>
        <p v-if="runs && runs.length >= limit" class="text-xs text-muted-foreground">
          Showing the latest {{ limit }} runs.
        </p>
      </div>
    </SheetContent>
  </Sheet>
</template>
