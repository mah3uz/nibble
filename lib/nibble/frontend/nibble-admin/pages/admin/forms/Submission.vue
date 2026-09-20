<script setup lang="ts">
import { Link, router } from '@inertiajs/vue3'
import { computed, ref } from 'vue'
import SubmissionFilesField from '@/components/admin/forms/SubmissionFilesField.vue'
import AdminIcon from '@/components/admin/icons/AdminIcon.vue'
import StatusCell from '@/components/admin/listing/cells/StatusCell.vue'
import PageHeader from '@/components/admin/page/PageHeader.vue'
import { Button } from '@/components/ui/button'
import { useConfirm } from '@/lib/confirm'
import { registerCoreFieldtypes } from '@nibble-admin/fieldtypes/core'
import { registerFieldtype } from '@nibble-admin/fieldtypes/registry'
import PublishContainer from '@nibble-admin/publish/PublishContainer.vue'
import PublishSections from '@nibble-admin/publish/PublishSections.vue'
import type { PublishBlueprint } from '@nibble-admin/fieldtypes/types'

registerCoreFieldtypes()
registerFieldtype('files', SubmissionFilesField)

type Delivery = {
  key: string
  target: string
  mode: string
  status: string
  attempts: number
  error?: string | null
  errors?: Record<string, string[]> | null
  at?: string | null
  can_retry: boolean
}

const props = defineProps<{
  form: { handle: string; title: string }
  submission: { id: number; status: string; created_at: string; deliveries: Delivery[] }
  blueprint: PublishBlueprint
  values: Record<string, unknown>
  meta: Record<string, unknown>
  can_delete: boolean
}>()

const confirm = useConfirm()
const values = ref(props.values)
const listUrl = computed(() => `/admin/forms/${props.form.handle}`)
const base = computed(() => `${listUrl.value}/submissions/${props.submission.id}`)
const date = (value: string) => new Date(value).toLocaleString(undefined, { dateStyle: 'medium', timeStyle: 'short' })

function retry(delivery: Delivery) {
  router.post(`${base.value}/deliveries/${encodeURIComponent(delivery.key)}/retry`, {}, { preserveScroll: true })
}

async function destroy() {
  const ok = await confirm({
    title: 'Delete this submission?',
    description: 'Its files and delivery logs are deleted too. This can’t be undone.',
    confirmText: 'Delete',
    dangerous: true,
  })
  if (ok) router.delete(base.value)
}
</script>

<template>
  <div class="mx-auto max-w-5xl">
    <Link
      :href="listUrl"
      class="relative z-10 -mb-6 flex w-fit items-center gap-1 pt-6 text-sm text-gray-600 hover:text-gray-900 dark:text-gray-400 dark:hover:text-white"
    >
      <AdminIcon name="chevron-left" class="size-4" />{{ form.title }}
    </Link>
    <PageHeader
      :title="date(submission.created_at)"
      icon="forms"
      :breadcrumbs="[
        { label: 'Forms', url: '/admin/forms' },
        { label: form.title, url: listUrl },
        { label: `Submission ${submission.id}` },
      ]"
    >
      <template #meta><StatusCell :value="submission.status" /></template>
      <template #actions>
        <Button v-if="can_delete" variant="outline" @click="destroy">Delete</Button>
      </template>
    </PageHeader>

    <PublishContainer v-model="values" :blueprint="blueprint" :meta="meta" read-only name="submission">
      <PublishSections :sections="blueprint.tabs[0].sections" />
    </PublishContainer>

    <section
      v-if="submission.deliveries.length"
      class="relative mb-6 w-full rounded-2xl bg-gray-150 p-1.75 pt-0 dark:bg-gray-950/35 dark:inset-shadow-2xs dark:inset-shadow-black"
    >
      <header class="px-4.5 py-3">
        <h3 class="text-sm font-medium tracking-tight text-gray-700 dark:text-white">Deliveries</h3>
      </header>
      <ul
        class="divide-y divide-gray-200 rounded-xl bg-white text-sm shadow-ui-md ring ring-gray-200 dark:divide-gray-700 dark:bg-gray-850 dark:ring-gray-700/80"
      >
        <li v-for="delivery in submission.deliveries" :key="delivery.key" class="flex items-start gap-4 px-4.5 py-3">
          <div class="min-w-0 flex-1 space-y-1">
            <div class="flex items-center gap-2">
              <span class="truncate font-medium" :title="delivery.target">{{ delivery.target }}</span>
              <StatusCell :value="delivery.status" />
            </div>
            <p class="text-xs text-gray-600 dark:text-gray-400">
              {{ delivery.mode === 'sync' ? 'During submission' : 'In the background' }} · {{ delivery.attempts }}
              {{ delivery.attempts === 1 ? 'attempt' : 'attempts' }}
              <template v-if="delivery.at"> · {{ date(delivery.at) }}</template>
            </p>
            <p v-if="delivery.error" class="text-xs text-red-700 dark:text-red-400">{{ delivery.error }}</p>
            <ul v-if="delivery.errors" class="text-xs text-red-700 dark:text-red-400">
              <li v-for="(messages, field) in delivery.errors" :key="field">{{ field }}: {{ messages.join(', ') }}</li>
            </ul>
          </div>
          <Button v-if="delivery.can_retry" size="sm" variant="outline" @click="retry(delivery)">Retry</Button>
        </li>
      </ul>
    </section>
  </div>
</template>
