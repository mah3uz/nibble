<script setup lang="ts">
import { computed, ref } from 'vue'
import { router } from '@inertiajs/vue3'
import CpIcon from '@/components/cp/icons/CpIcon.vue'
import CpPanel from '@/components/cp/page/CpPanel.vue'
import ReleaseNotes from '@/components/cp/ReleaseNotes.vue'
import PageHeader from '@/components/cp/page/PageHeader.vue'
import { Button } from '@/components/ui/button'
import { Switch } from '@/components/ui/switch'
import { Dialog, DialogContent, DialogDescription, DialogHeader, DialogTitle } from '@/components/ui/dialog'
import { useBreadcrumbs } from '@/lib/breadcrumbs'

type Release = {
  version: string
  url: string | null
  date: string | null
  security: boolean
  status: 'newer' | 'current' | 'older'
  body: string
}

const props = defineProps<{
  current: string
  checking: boolean
  waiting: { count: number; security: boolean }
  releases: Release[]
  page: number
  more: boolean
}>()

useBreadcrumbs([{ label: 'Updates' }])

const asking = ref<Release | null>(null)
const copied = ref(false)

const risky = computed(() => props.waiting.security)
const loading = ref(false)
const fresh = ref(new Set<string>())

// Only what just arrived glows, so the eye finds where the list grew.
function loadMore() {
  const before = new Set(props.releases.map((release) => release.version))
  router.reload({
    only: ['releases', 'page', 'more'],
    data: { page: props.page + 1 },
    preserveUrl: true,
    onStart: () => (loading.value = true),
    onFinish: () => (loading.value = false),
    onSuccess: () => {
      fresh.value = new Set(props.releases.map((release) => release.version).filter((version) => !before.has(version)))
      setTimeout(() => (fresh.value = new Set()), 1400)
    },
  })
}

const command = (release: Release) => `bin/rails nibble:upgrade ${release.version}`

const released = (value: string | null) =>
  value ? new Date(value).toLocaleDateString(undefined, { dateStyle: 'medium' }) : null

function setChecking(on: boolean) {
  router.patch('/cp/updates', { checking: on }, { preserveScroll: true })
}

function copy(release: Release) {
  navigator.clipboard.writeText(command(release))
  copied.value = true
  setTimeout(() => (copied.value = false), 2000)
}
</script>

<template>
  <div class="mx-auto max-w-5xl">
    <PageHeader title="Updates" icon="download" :breadcrumbs="[{ label: 'Updates' }]">
      <template #meta>
        <span class="text-sm text-gray-600 tabular-nums dark:text-gray-400">{{ current }}</span>
        <span
          v-if="risky"
          class="rounded-md border border-red-300 bg-red-50 px-2 py-0.5 text-xs font-medium text-red-700 dark:border-red-500/40 dark:bg-red-500/10 dark:text-red-400"
          >Security update available</span
        >
        <span
          v-else-if="waiting.count"
          class="rounded-md border border-amber-300 bg-amber-50 px-2 py-0.5 text-xs font-medium text-amber-700 dark:border-amber-500/40 dark:bg-amber-500/10 dark:text-amber-400"
          >Update available</span
        >
      </template>
      <template #actions>
        <label class="flex items-center gap-2.5 text-sm text-gray-600 dark:text-gray-400">
          <Switch :model-value="props.checking" @update:model-value="setChecking" />
          Check for updates
        </label>
      </template>
    </PageHeader>

    <CpPanel v-if="!props.checking" title="Not checking">
      <p class="text-sm text-gray-600 dark:text-gray-400">
        Nibble is not looking for releases, so nothing reaches this site and nothing leaves it. Turn the switch above
        back on to hear about them.
      </p>
    </CpPanel>

    <template v-else>
      <CpPanel v-if="!props.releases.length" title="Nothing to show yet">
        <p class="text-sm text-gray-600 dark:text-gray-400">
          Nibble checks for releases once a day. Nothing has come back yet.
        </p>
      </CpPanel>

      <template v-else>
        <CpPanel v-if="!waiting.count" title="Up to date" class="mb-4">
          <p class="text-sm text-gray-600 dark:text-gray-400">{{ current }} is the newest release.</p>
        </CpPanel>

        <CpPanel
          v-for="release in props.releases"
          :key="release.version"
          flush
          class="mb-4 transition-[background-color,box-shadow] duration-1000 last:mb-0"
          :class="fresh.has(release.version) ? 'bg-blue-50 ring-2 ring-blue-400 duration-0 dark:bg-blue-500/10' : ''"
        >
          <div class="flex items-center justify-between border-b border-gray-100 px-4.5 py-3 dark:border-gray-800">
            <div>
              <div class="flex items-center gap-2">
                <span class="font-medium tabular-nums">{{ release.version }}</span>
                <span
                  v-if="release.security"
                  class="rounded bg-red-100 px-1.5 py-0.5 text-[11px] font-medium text-red-700 dark:bg-red-500/15 dark:text-red-400"
                  >Security</span
                >
                <span
                  v-if="release.status === 'current'"
                  class="rounded bg-gray-100 px-1.5 py-0.5 text-[11px] font-medium text-gray-600 dark:bg-gray-800 dark:text-gray-400"
                  >You are here</span
                >
              </div>
              <div v-if="released(release.date)" class="text-xs text-gray-500">
                Released on {{ released(release.date) }}
              </div>
            </div>
            <Button v-if="release.status === 'newer'" variant="outline" size="sm" @click="asking = release">
              <CpIcon name="clipboard" class="size-3.5" />
              Get command
            </Button>
          </div>
          <div v-if="release.body" class="px-4.5 py-3">
            <ReleaseNotes :source="release.body" />
          </div>
          <p v-if="release.url" class="px-4.5 pb-3 text-sm">
            <a
              :href="release.url"
              target="_blank"
              rel="noreferrer"
              class="text-blue-600 hover:underline dark:text-blue-400"
              >Full notes</a
            >
          </p>
        </CpPanel>

        <div v-if="props.more" class="mt-6 flex justify-center">
          <Button variant="outline" :disabled="loading" @click="loadMore">
            {{ loading ? 'Loading…' : 'Load more' }}
          </Button>
        </div>
      </template>
    </template>

    <Dialog :open="!!asking" @update:open="asking = null">
      <DialogContent class="sm:max-w-lg">
        <DialogHeader>
          <DialogTitle>Update to {{ asking?.version }}</DialogTitle>
          <DialogDescription>
            Run this on your own machine, not on the server. It stops if anything is uncommitted.
          </DialogDescription>
        </DialogHeader>
        <button
          type="button"
          class="flex w-full items-center justify-between gap-3 rounded-md bg-gray-900 px-3 py-2.5 text-left font-mono text-sm text-gray-100 dark:bg-gray-950"
          @click="asking && copy(asking)"
        >
          <span>{{ asking ? command(asking) : '' }}</span>
          <span class="flex shrink-0 items-center gap-1.5 text-xs opacity-70">
            <CpIcon name="clipboard" class="size-4" />
            {{ copied ? 'Copied' : 'Copy' }}
          </span>
        </button>
      </DialogContent>
    </Dialog>
  </div>
</template>
