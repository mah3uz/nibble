<script setup lang="ts">
import { ref } from 'vue'
import AdminIcon from '@/components/admin/icons/AdminIcon.vue'
import AdminPanel from '@/components/admin/page/AdminPanel.vue'
import PageHeader from '@/components/admin/page/PageHeader.vue'
import { Button } from '@/components/ui/button'
import { Dialog, DialogContent, DialogDescription, DialogHeader, DialogTitle } from '@/components/ui/dialog'
import { useBreadcrumbs } from '@/lib/breadcrumbs'

type Release = { version: string; url: string | null; date: string | null; notes: string[] }

const props = defineProps<{ current: string; feed: boolean; releases: Release[] }>()

useBreadcrumbs([{ label: 'Utilities', url: '/admin/utilities' }, { label: 'Updates' }])

const asking = ref<Release | null>(null)
const copied = ref(false)

const command = (release: Release) => `bin/nibble-upgrade ${release.version}`

const released = (value: string | null) =>
  value ? new Date(value).toLocaleDateString(undefined, { dateStyle: 'medium' }) : null

function copy(release: Release) {
  navigator.clipboard.writeText(command(release))
  copied.value = true
  setTimeout(() => (copied.value = false), 2000)
}
</script>

<template>
  <div>
    <PageHeader
      title="Updates"
      icon="download"
      :breadcrumbs="[{ label: 'Utilities', url: '/admin/utilities' }, { label: 'Updates' }]"
    >
      <template #meta>
        <span class="text-sm text-gray-600 tabular-nums dark:text-gray-400">{{ current }}</span>
        <span
          v-if="props.releases.length"
          class="rounded-md border border-amber-300 bg-amber-50 px-2 py-0.5 text-xs font-medium text-amber-700 dark:border-amber-500/40 dark:bg-amber-500/10 dark:text-amber-400"
          >Update available</span
        >
      </template>
    </PageHeader>

    <AdminPanel v-if="!props.feed" title="Not checking">
      <p class="text-sm text-gray-600 dark:text-gray-400">
        Nibble only looks for releases when you point it at one. Set
        <code class="rounded bg-gray-100 px-1 py-0.5 text-xs dark:bg-gray-800">release_feed</code> in
        <code class="rounded bg-gray-100 px-1 py-0.5 text-xs dark:bg-gray-800">config/nibble.yml</code>
        to the URL of a published release file. It is read, and nothing about this site is sent.
      </p>
    </AdminPanel>

    <AdminPanel v-else-if="!props.releases.length" title="Up to date">
      <p class="text-sm text-gray-600 dark:text-gray-400">
        {{ current }} is the newest release. This is checked every few hours.
      </p>
    </AdminPanel>

    <AdminPanel v-for="release in props.releases" v-else :key="release.version" flush class="mb-4 last:mb-0">
      <div class="flex items-center justify-between border-b border-gray-100 px-4.5 py-3 dark:border-gray-800">
        <div>
          <div class="font-medium tabular-nums">{{ release.version }}</div>
          <div v-if="released(release.date)" class="text-xs text-gray-500">
            Released on {{ released(release.date) }}
          </div>
        </div>
        <Button variant="outline" size="sm" @click="asking = release">
          <AdminIcon name="clipboard" class="size-3.5" />
          Get command
        </Button>
      </div>
      <ul
        v-if="release.notes.length"
        class="list-disc space-y-1 py-3 ps-9 pe-4.5 text-sm text-gray-700 dark:text-gray-300"
      >
        <li v-for="(note, index) in release.notes" :key="index">{{ note }}</li>
      </ul>
      <p v-if="release.url" class="px-4.5 pb-3 text-sm">
        <a :href="release.url" target="_blank" rel="noreferrer" class="text-blue-600 hover:underline dark:text-blue-400"
          >Full notes</a
        >
      </p>
    </AdminPanel>

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
            <AdminIcon name="clipboard" class="size-4" />
            {{ copied ? 'Copied' : 'Copy' }}
          </span>
        </button>
      </DialogContent>
    </Dialog>
  </div>
</template>
