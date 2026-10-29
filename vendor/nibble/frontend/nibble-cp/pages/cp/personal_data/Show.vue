<script setup lang="ts">
import { router } from '@inertiajs/vue3'
import { ref } from 'vue'
import DataTablePanel from '@/components/cp/page/DataTablePanel.vue'
import PageHeader from '@/components/cp/page/PageHeader.vue'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { useConfirm } from '@/lib/confirm'

type FormRow = { handle: string; title: string; removed: boolean; count: number }

const props = defineProps<{ email: string; searched: boolean; total: number; forms: FormRow[] }>()

const confirm = useConfirm()
const email = ref(props.email)

function search() {
  router.visit('/cp/personal-data', { data: { email: email.value } })
}

function download(format: 'json' | 'csv') {
  window.open(`/cp/personal-data/export.${format}?email=${encodeURIComponent(props.email)}`, '_blank')
}

async function erase() {
  const ok = await confirm({
    title: `Erase ${props.total} ${props.total === 1 ? 'submission' : 'submissions'}?`,
    description: `Every submission containing ${props.email}, in every form, is deleted with its uploaded files. This can’t be undone.`,
    confirmText: 'Erase',
    dangerous: true,
  })
  if (ok) router.delete(`/cp/personal-data?email=${encodeURIComponent(props.email)}`)
}
</script>

<template>
  <div class="mx-auto max-w-5xl space-y-6">
    <PageHeader
      title="Personal data"
      icon="forms"
      :breadcrumbs="[{ label: 'Forms', url: '/cp/forms' }, { label: 'Personal data' }]"
    />

    <p class="text-sm text-gray-600 dark:text-gray-400">
      Find every submission, in every form, whose fields contain an email address. Export what a person is owed or erase
      it on request. Exports and erasures are recorded in the audit log.
    </p>

    <form class="flex max-w-xl gap-2" @submit.prevent="search">
      <Input v-model="email" type="email" required aria-label="Email address" placeholder="jane@example.com" />
      <Button type="submit">Find</Button>
    </form>

    <template v-if="searched">
      <p v-if="!total" class="text-sm">No submissions contain {{ props.email }}.</p>
      <template v-else>
        <DataTablePanel>
          <thead>
            <tr>
              <th>Form</th>
              <th class="w-40">Submissions</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="form in forms" :key="form.handle">
              <td>
                {{ form.title }}<span v-if="form.removed" class="ms-2 text-xs text-gray-500">Not in the schema</span>
              </td>
              <td>{{ form.count }}</td>
            </tr>
          </tbody>
        </DataTablePanel>
        <div class="flex gap-2">
          <Button variant="outline" @click="download('json')">Export JSON</Button>
          <Button variant="outline" @click="download('csv')">Export CSV</Button>
          <Button variant="outline" @click="erase">Erase</Button>
        </div>
      </template>
    </template>
  </div>
</template>
