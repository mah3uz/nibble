<script setup lang="ts">
import { InfiniteScroll } from '@inertiajs/vue3'
import { onBeforeUnmount, ref, watch } from 'vue'
import CpPanel from '@/components/cp/page/CpPanel.vue'
import PageHeader from '@/components/cp/page/PageHeader.vue'
import { Button } from '@/components/ui/button'
import { useBreadcrumbs } from '@/lib/breadcrumbs'

type Row = {
  id: number
  action: string
  at: string
  ip: string | null
  actor: string | null
  subject: string
  changed: string[]
}

const props = defineProps<{ audit: Row[] }>()

const HIGHLIGHT_MS = 2500
const fresh = ref(new Set<number>())
const announcement = ref('')
let known = new Set(props.audit.map((row) => row.id))
let timer: ReturnType<typeof setTimeout> | undefined

watch(
  () => props.audit.length,
  () => {
    const added = props.audit.filter((row) => !known.has(row.id)).map((row) => row.id)
    known = new Set(props.audit.map((row) => row.id))
    if (!added.length) return

    fresh.value = new Set(added)
    announcement.value = `${added.length} older ${added.length === 1 ? 'entry' : 'entries'} loaded`
    clearTimeout(timer)
    timer = setTimeout(() => (fresh.value = new Set()), HIGHLIGHT_MS)
  },
)
onBeforeUnmount(() => clearTimeout(timer))

const verb = (action: string) => {
  const [area, name] = action.split('.')
  const words = (name ?? area).replaceAll('_', ' ')
  return words.charAt(0).toUpperCase() + words.slice(1)
}
const area = (action: string) => (action.startsWith('auth.') ? 'Sign-in & access' : 'Content')
const date = (value: string) => new Date(value).toLocaleString(undefined, { dateStyle: 'medium', timeStyle: 'short' })

useBreadcrumbs([{ label: 'Utilities', url: '/cp/utilities' }, { label: 'Audit log' }])
</script>

<template>
  <div>
    <PageHeader
      title="Audit log"
      icon="history"
      :breadcrumbs="[{ label: 'Utilities', url: '/cp/utilities' }, { label: 'Audit log' }]"
    />

    <CpPanel title="Activity" description="Every recorded action, newest first." flush>
      <p v-if="!audit.length" class="px-4.5 py-4 text-sm text-gray-500">Nothing has been recorded yet.</p>
      <InfiniteScroll v-else data="audit" manual only-next preserve-url>
        <ul class="text-sm">
          <li
            v-for="row in audit"
            :key="row.id"
            :class="[
              'flex flex-wrap items-baseline gap-x-3 gap-y-1 border-b border-gray-100 px-4.5 py-3 transition-colors duration-1000 last:border-0 motion-reduce:transition-none dark:border-gray-800',
              fresh.has(row.id) ? 'bg-amber-50 dark:bg-amber-400/10' : 'bg-transparent',
            ]"
          >
            <span class="font-medium text-gray-900 dark:text-white">{{ verb(row.action) }}</span>
            <span class="text-gray-600 dark:text-gray-400">{{ row.subject }}</span>
            <span v-if="row.changed.length" class="flex flex-wrap gap-1">
              <code
                v-for="field in row.changed.slice(0, 6)"
                :key="field"
                class="rounded bg-gray-100 px-1.5 text-xs text-gray-700 dark:bg-gray-800 dark:text-gray-300"
                >{{ field }}</code
              >
              <span v-if="row.changed.length > 6" class="text-xs text-gray-500">+{{ row.changed.length - 6 }}</span>
            </span>
            <span class="ms-auto flex items-baseline gap-2 text-xs text-gray-500">
              <span class="rounded-full bg-gray-100 px-2 py-0.5 text-gray-700 dark:bg-gray-800 dark:text-gray-300">{{
                area(row.action)
              }}</span>
              {{ row.actor ?? 'system' }} · {{ date(row.at) }}
            </span>
          </li>
        </ul>

        <template #next="{ fetch, loading, hasMore }">
          <div class="flex justify-center border-t border-gray-100 px-4.5 py-3 dark:border-gray-800">
            <Button v-if="hasMore" variant="outline" size="sm" :disabled="loading" @click="fetch">
              {{ loading ? 'Loading…' : 'Show more' }}
            </Button>
            <p v-else class="text-sm text-gray-500">That's everything recorded.</p>
          </div>
        </template>
      </InfiniteScroll>
      <p class="sr-only" aria-live="polite">{{ announcement }}</p>
    </CpPanel>
  </div>
</template>
