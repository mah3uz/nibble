<script setup lang="ts">
import { router } from '@inertiajs/vue3'
import { onMounted, ref } from 'vue'
import CpIcon from '@/components/cp/icons/CpIcon.vue'
import { Button } from '@/components/ui/button'
import { Popover, PopoverContent, PopoverTrigger } from '@/components/ui/popover'
import { timeAgo } from '@/lib/format'

type Notification = {
  id: number
  kind: string
  at: string
  read: boolean
  title: string | null
  comment: string | null
  url: string | null
}

const LINES: Record<string, string> = {
  'workflow.review_requested': 'asked for a review of',
  'workflow.approved': 'approved',
  'workflow.rejected': 'sent back',
  'comment.mentioned': 'mentioned you on',
  'form.submitted': 'New submission to',
  'webhook.disabled': 'Turned off after repeated failures:',
  'apps.connected': 'New app connected to your account:',
  'apps.approval_requested': 'Waiting for your approval:',
}

const ICONS: Record<string, string> = {
  'workflow.review_requested': 'edit',
  'workflow.approved': 'edit',
  'workflow.rejected': 'edit',
  'comment.mentioned': 'user-avatar',
  'form.submitted': 'forms',
  'webhook.disabled': 'webhooks',
  'apps.connected': 'key',
  'apps.approval_requested': 'fingerprint',
}

const items = ref<Notification[]>([])
const unread = ref(0)
const open = ref(false)

async function load() {
  const response = await fetch('/cp/notifications', { headers: { Accept: 'application/json' } })
  if (!response.ok) return
  const payload = await response.json()
  items.value = payload.notifications
  unread.value = payload.unread
}

async function send(method: 'PUT' | 'DELETE', id?: number) {
  const csrf = document.querySelector<HTMLMetaElement>('meta[name=csrf-token]')?.content ?? ''
  const response = await fetch(id ? `/cp/notifications/${id}` : '/cp/notifications', {
    method,
    headers: { Accept: 'application/json', 'X-CSRF-Token': csrf },
  })
  if (!response.ok) return
  const payload = await response.json()
  items.value = payload.notifications
  unread.value = payload.unread
}

const markRead = (id?: number) => send('PUT', id)
const remove = (id?: number) => send('DELETE', id)

function markAllRead() {
  void markRead()
}

async function go(item: Notification) {
  open.value = false
  if (!item.read) await markRead(item.id)
  if (item.url) router.visit(item.url)
}

onMounted(load)
</script>

<template>
  <Popover v-model:open="open">
    <PopoverTrigger as-child>
      <button
        type="button"
        class="relative inline-flex size-8 cursor-pointer items-center justify-center rounded-lg text-white/85 hover:bg-white/15"
        :aria-label="unread ? `Notifications, ${unread} unread` : 'Notifications'"
        @click="load"
      >
        <CpIcon name="bell" class="size-4" />
        <span v-if="unread" class="absolute top-1.5 right-1.5 size-2 rounded-full bg-rose-500 ring-2 ring-header" />
      </button>
    </PopoverTrigger>
    <PopoverContent align="end" class="w-96 overflow-hidden bg-gray-50 p-0 dark:bg-gray-800">
      <header
        class="flex items-center gap-2 border-b border-gray-200 bg-white px-3.5 py-2.5 dark:border-black dark:bg-gray-850"
      >
        <span class="text-sm font-medium text-gray-900 dark:text-gray-200">Notifications</span>
        <span
          v-if="unread"
          class="rounded-full bg-gray-100 px-1.5 text-2xs leading-4.5 font-medium text-gray-600 dark:bg-white/10 dark:text-gray-300"
          >{{ unread }} new</span
        >
        <Button v-if="unread" variant="ghost" size="xs" class="ms-auto -me-1.5 text-gray-600" @click="markAllRead"
          >Mark all read</Button
        >
      </header>
      <div class="bg-white shadow-ui-xs dark:bg-gray-850" :class="items.length ? 'rounded-b-xl p-1.5' : 'rounded-b-xl'">
        <div v-if="!items.length" class="flex flex-col items-center gap-2 px-4 py-8 text-center">
          <CpIcon name="bell" class="size-5 text-gray-400" />
          <p class="text-sm text-gray-500 dark:text-gray-400">You're all caught up.</p>
        </div>
        <ul v-else class="max-h-96 space-y-0.5 overflow-y-auto" role="list">
          <li v-for="item in items" :key="item.id" class="group relative">
            <button
              type="button"
              class="flex w-full cursor-pointer items-start gap-2.5 rounded-lg py-2 ps-2 pe-9 text-left text-sm hover:bg-gray-100 focus-visible:bg-gray-100 focus-visible:outline-none dark:hover:bg-white/7 dark:focus-visible:bg-white/7"
              @click="go(item)"
            >
              <span
                class="mt-px flex size-6 shrink-0 items-center justify-center rounded-md bg-gray-100 text-gray-500 dark:bg-white/7 dark:text-gray-400"
              >
                <CpIcon :name="ICONS[item.kind] ?? 'bell'" class="size-3.5" />
              </span>
              <span class="min-w-0 flex-1">
                <span
                  class="block"
                  :class="item.read ? 'text-gray-500 dark:text-gray-400' : 'text-gray-900 dark:text-gray-200'"
                  >{{ LINES[item.kind] ?? item.kind }}
                  <span class="font-medium">{{ item.title ?? 'a record' }}</span></span
                >
                <span v-if="item.comment" class="mt-0.5 block truncate text-xs text-gray-500">{{ item.comment }}</span>
                <time :datetime="item.at" class="mt-0.5 block text-xs text-gray-400">{{ timeAgo(item.at) }}</time>
              </span>
              <span v-if="!item.read" class="mt-2 size-1.5 shrink-0 rounded-full bg-rose-500" aria-label="Unread" />
            </button>
            <Button
              variant="ghost"
              size="icon-xs"
              class="absolute top-1.5 right-1.5 text-gray-400 hover:text-gray-900 dark:hover:text-white pointer-fine:not-group-hover:not-focus-visible:opacity-0"
              :aria-label="`Remove notification: ${LINES[item.kind] ?? item.kind} ${item.title ?? 'a record'}`"
              @click="remove(item.id)"
            >
              <CpIcon name="x" class="size-3" />
            </Button>
          </li>
        </ul>
      </div>
      <footer v-if="items.length" class="flex justify-end px-1.75 py-1.5">
        <Button variant="ghost" size="xs" class="text-gray-600 dark:text-gray-400" @click="remove()">Clear all</Button>
      </footer>
    </PopoverContent>
  </Popover>
</template>
