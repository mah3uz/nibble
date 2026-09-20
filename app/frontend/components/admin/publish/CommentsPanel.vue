<script setup lang="ts">
import { onMounted, ref } from 'vue'
import { Button } from '@/components/ui/button'
import { Textarea } from '@/components/ui/textarea'
import { toast } from 'vue-sonner'

type Comment = { id: number; body: string; at: string; author: string | null; mine: boolean; replies?: Comment[] }

const props = defineProps<{ url: string }>()

const comments = ref<Comment[]>([])
const draft = ref('')
const replyTo = ref<number | null>(null)
const replyDraft = ref('')
const busy = ref(false)

async function send(method: 'GET' | 'POST' | 'DELETE', url: string, body?: unknown) {
  const csrf = document.querySelector<HTMLMetaElement>('meta[name=csrf-token]')?.content ?? ''
  const response = await fetch(url, {
    method,
    headers: { 'Content-Type': 'application/json', Accept: 'application/json', 'X-CSRF-Token': csrf },
    body: body ? JSON.stringify(body) : undefined,
  })
  if (!response.ok) {
    toast.error("That note couldn't be saved.")
    return null
  }
  return response.json()
}

async function load() {
  const payload = await send('GET', props.url)
  if (payload) comments.value = payload.comments
}

async function post(body: string, parentId: number | null) {
  if (!body.trim() || busy.value) return
  busy.value = true
  const payload = await send('POST', props.url, { comment: { body, parent_id: parentId } })
  busy.value = false
  if (!payload) return
  comments.value = payload.comments
  draft.value = ''
  replyDraft.value = ''
  replyTo.value = null
}

async function remove(id: number) {
  const payload = await send('DELETE', `${props.url}/${id}`)
  if (payload) comments.value = payload.comments
}

const when = (iso: string) => new Date(iso).toLocaleString('en-AU', { dateStyle: 'medium', timeStyle: 'short' })

onMounted(load)
</script>

<template>
  <section class="space-y-3" aria-label="Editorial notes">
    <h2 class="text-sm font-medium text-gray-700 dark:text-gray-300">Notes</h2>

    <form class="space-y-2" @submit.prevent="post(draft, null)">
      <Textarea v-model="draft" rows="2" placeholder="Leave a note. @mention someone to tell them." />
      <Button type="submit" size="sm" variant="outline" :disabled="!draft.trim() || busy">Add note</Button>
    </form>

    <ul v-if="comments.length" class="space-y-3" role="list">
      <li
        v-for="comment in comments"
        :key="comment.id"
        class="rounded-lg border border-gray-200 p-3 dark:border-gray-700"
      >
        <div class="flex items-baseline justify-between gap-2">
          <span class="text-sm font-medium text-gray-900 dark:text-gray-200">{{ comment.author ?? 'Someone' }}</span>
          <span class="text-xs text-muted-foreground">{{ when(comment.at) }}</span>
        </div>
        <p class="mt-1 text-sm whitespace-pre-wrap text-gray-700 dark:text-gray-300">{{ comment.body }}</p>
        <div class="mt-2 flex gap-2">
          <Button
            variant="link"
            size="sm"
            class="h-auto p-0"
            @click="replyTo = replyTo === comment.id ? null : comment.id"
            >Reply</Button
          >
          <Button v-if="comment.mine" variant="link" size="sm" class="h-auto p-0" @click="remove(comment.id)"
            >Delete</Button
          >
        </div>

        <form v-if="replyTo === comment.id" class="mt-2 space-y-2" @submit.prevent="post(replyDraft, comment.id)">
          <Textarea v-model="replyDraft" rows="2" placeholder="Reply…" />
          <Button type="submit" size="sm" variant="outline" :disabled="!replyDraft.trim() || busy">Reply</Button>
        </form>

        <ul v-if="comment.replies?.length" class="mt-3 space-y-2 border-s border-gray-200 ps-3 dark:border-gray-700">
          <li v-for="reply in comment.replies" :key="reply.id">
            <div class="flex items-baseline justify-between gap-2">
              <span class="text-sm font-medium text-gray-900 dark:text-gray-200">{{ reply.author ?? 'Someone' }}</span>
              <span class="text-xs text-muted-foreground">{{ when(reply.at) }}</span>
            </div>
            <p class="text-sm whitespace-pre-wrap text-gray-700 dark:text-gray-300">{{ reply.body }}</p>
            <Button v-if="reply.mine" variant="link" size="sm" class="h-auto p-0" @click="remove(reply.id)"
              >Delete</Button
            >
          </li>
        </ul>
      </li>
    </ul>
    <p v-else class="text-sm text-muted-foreground">No notes yet.</p>
  </section>
</template>
