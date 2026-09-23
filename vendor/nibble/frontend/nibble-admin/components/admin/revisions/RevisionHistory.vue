<script setup lang="ts">
import { router } from '@inertiajs/vue3'
import { computed, ref, watch } from 'vue'
import { toast } from 'vue-sonner'
import { Button } from '@/components/ui/button'
import { Sheet, SheetContent, SheetHeader, SheetTitle } from '@/components/ui/sheet'
import { useConfirm } from '@/lib/confirm'
import RevisionItem, { type Version } from './RevisionItem.vue'

const props = defineProps<{ open: boolean; url: string }>()
const emit = defineEmits<{ 'update:open': [boolean] }>()

type Payload = {
  record: { id: number; type: 'post' | 'page'; title: string; path: string; lock_version: number; live: boolean }
  versions: Version[]
  pagination: { page: number; per_page: number; total: number; pages: number }
}
const payload = ref<Payload | null>(null)
const loading = ref(false)
const page = ref(1)

async function load() {
  loading.value = true
  try {
    const response = await fetch(page.value > 1 ? `${props.url}?page=${page.value}` : props.url, {
      headers: { Accept: 'application/json' },
    })
    if (!response.ok) toast.error("Couldn't load the revision history.")
    payload.value = response.ok ? await response.json() : null
  } finally {
    loading.value = false
  }
}

watch(
  () => props.open,
  (open) => {
    if (!open) return
    page.value = 1
    load()
  },
  { immediate: true },
)
watch(page, load)

const groups = computed(() => {
  const byDay = new Map<string, Version[]>()
  for (const version of payload.value?.versions ?? []) {
    const day = new Date(version.created_at).toLocaleDateString('en-AU', {
      weekday: 'long',
      day: 'numeric',
      month: 'long',
    })
    byDay.set(day, [...(byDay.get(day) ?? []), version])
  }
  return [...byDay.entries()].map(([day, versions]) => ({ day, versions }))
})

const confirmRestore = useConfirm()
async function restore(version: Version) {
  const record = payload.value?.record
  if (!record) return

  const ok = await confirmRestore({
    title: `Restore this ${record.type}'s content from ${new Date(version.created_at).toLocaleString('en-AU', { dateStyle: 'medium', timeStyle: 'short' })}?`,
    description: record.live
      ? 'Restored into unpublished changes — review and publish to make it live.'
      : 'This is saved as a new version.',
    confirmText: 'Restore',
  })
  if (ok) router.post(`${props.url}/${version.id}/restore`, { lock_version: record.lock_version })
}
</script>

<template>
  <Sheet :open="open" @update:open="emit('update:open', $event)">
    <SheetContent size="narrow" class="gap-0">
      <SheetHeader>
        <SheetTitle>History</SheetTitle>
      </SheetHeader>
      <div class="flex-1 space-y-4 overflow-y-auto p-6">
        <p v-if="loading && !payload" class="text-sm text-muted-foreground">Loading…</p>
        <p v-else-if="payload && !payload.versions.length" class="text-sm text-muted-foreground">No history yet.</p>
        <div v-for="group in groups" :key="group.day" class="space-y-2">
          <div class="text-xs font-medium tracking-wide text-muted-foreground uppercase">{{ group.day }}</div>
          <RevisionItem
            v-for="version in group.versions"
            :key="version.id"
            :version="version"
            :preview-url="`${url}/${version.id}/preview`"
            @restore="restore(version)"
          />
        </div>
      </div>
      <div
        v-if="payload && payload.pagination.pages > 1"
        class="flex items-center justify-between border-t p-4 text-sm text-muted-foreground"
      >
        <Button variant="outline" size="sm" :disabled="page <= 1" @click="page--">Newer</Button>
        <span>Page {{ payload.pagination.page }} of {{ payload.pagination.pages }}</span>
        <Button variant="outline" size="sm" :disabled="page >= payload.pagination.pages" @click="page++">Older</Button>
      </div>
    </SheetContent>
  </Sheet>
</template>
