<script setup lang="ts">
import { router } from '@inertiajs/vue3'
import { onMounted, ref } from 'vue'
import AdminIcon from '@/components/admin/icons/AdminIcon.vue'
import { Button } from '@/components/ui/button'
import { Popover, PopoverContent, PopoverTrigger } from '@/components/ui/popover'

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
}

const items = ref<Notification[]>([])
const unread = ref(0)
const open = ref(false)

async function load() {
  const response = await fetch('/admin/notifications', { headers: { Accept: 'application/json' } })
  if (!response.ok) return
  const payload = await response.json()
  items.value = payload.notifications
  unread.value = payload.unread
}

async function send(method: 'PUT' | 'DELETE', id?: number) {
  const csrf = document.querySelector<HTMLMetaElement>('meta[name=csrf-token]')?.content ?? ''
  const response = await fetch(id ? `/admin/notifications/${id}` : '/admin/notifications', {
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
        <AdminIcon name="bell" class="size-4" />
        <span v-if="unread" class="absolute top-1.5 right-1.5 size-2 rounded-full bg-rose-500 ring-2 ring-header" />
      </button>
    </PopoverTrigger>
    <PopoverContent align="end" class="w-80 p-0">
      <div class="flex items-center justify-between px-4 py-2">
        <span class="text-sm font-medium">Notifications</span>
        <div class="flex items-center gap-3">
          <Button v-if="unread" variant="link" size="sm" class="h-auto p-0" @click="markAllRead">Mark all read</Button>
          <Button v-if="items.length" variant="link" size="sm" class="h-auto p-0" @click="remove()">Clear all</Button>
        </div>
      </div>
      <p v-if="!items.length" class="px-4 pb-3 text-sm text-muted-foreground">Nothing yet.</p>
      <ul v-else class="max-h-80 divide-y divide-gray-200 overflow-y-auto dark:divide-gray-700" role="list">
        <li v-for="item in items" :key="item.id" class="group relative">
          <button
            type="button"
            class="w-full cursor-pointer py-2 ps-4 pe-10 text-left text-sm hover:bg-gray-50 dark:hover:bg-gray-800"
            :class="item.read ? 'text-muted-foreground' : 'text-gray-900 dark:text-gray-100'"
            @click="go(item)"
          >
            <span>{{ LINES[item.kind] ?? item.kind }} {{ item.title ?? 'a record' }}</span>
            <span v-if="item.comment" class="mt-0.5 block truncate text-xs text-muted-foreground">{{
              item.comment
            }}</span>
          </button>
          <button
            type="button"
            class="absolute top-2 right-2 inline-flex size-6 cursor-pointer items-center justify-center rounded-md text-gray-500 hover:bg-gray-400/15 hover:text-gray-900 dark:hover:text-white pointer-fine:not-group-hover:not-focus-visible:opacity-0"
            :aria-label="`Remove notification: ${LINES[item.kind] ?? item.kind} ${item.title ?? 'a record'}`"
            @click="remove(item.id)"
          >
            <AdminIcon name="x" class="size-3" />
          </button>
        </li>
      </ul>
    </PopoverContent>
  </Popover>
</template>
