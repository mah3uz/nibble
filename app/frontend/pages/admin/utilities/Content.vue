<script setup lang="ts">
import { useForm } from '@inertiajs/vue3'
import { computed } from 'vue'
import AdminPanel from '@/components/admin/page/AdminPanel.vue'
import PageHeader from '@/components/admin/page/PageHeader.vue'
import { Button } from '@/components/ui/button'
import { Checkbox } from '@/components/ui/checkbox'
import { Label } from '@/components/ui/label'
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select'
import { useBreadcrumbs } from '@/lib/breadcrumbs'

type Report = {
  imported: boolean
  ok: boolean
  mode: 'create' | 'update'
  created: number
  updated: number
  skipped: number
  errors: string[]
  more_errors: number
}

const props = defineProps<{ can_export: boolean; can_import: boolean; report: Report | null }>()

const form = useForm({ package: null as File | null, mode: 'create', webhooks: false, confirm: '0' })

const checked = computed(() => !!props.report && props.report.ok && !props.report.imported)

function pick(event: Event) {
  form.package = (event.target as HTMLInputElement).files?.[0] ?? null
}

function send(confirm: boolean) {
  form
    .transform((data) => ({ ...data, webhooks: data.webhooks ? '1' : '0', confirm: confirm ? '1' : '0' }))
    .post('/admin/utilities/content/import', { forceFormData: true, preserveState: true, preserveScroll: true })
}

async function importPackage() {
  send(true)
}

const summary = (report: Report) =>
  `${report.imported ? 'Created' : 'Would create'} ${report.created}, ` +
  `${report.imported ? 'updated' : 'update'} ${report.updated}, ` +
  `and ${report.imported ? 'left' : 'leave'} ${report.skipped} as they were.`

useBreadcrumbs([{ label: 'Utilities', url: '/admin/utilities' }, { label: 'Content' }])
</script>

<template>
  <div>
    <PageHeader
      title="Content"
      icon="package"
      :breadcrumbs="[{ label: 'Utilities', url: '/admin/utilities' }, { label: 'Content' }]"
    />

    <AdminPanel v-if="!can_export && !can_import">
      <p class="text-sm text-gray-600 dark:text-gray-400">
        Exporting and importing content needs its own permission, which your roles don't include.
      </p>
    </AdminPanel>

    <AdminPanel v-if="can_export" title="Export">
      <template #actions>
        <Button as-child variant="outline" size="sm">
          <a href="/admin/utilities/content/export" download>Download package</a>
        </Button>
      </template>
      <p class="text-sm text-gray-600 dark:text-gray-400">
        Every entry, term, global set, menu and redirect, drafts included, as a zip another Nibble site can import.
        Asset files aren't included; only their details are.
      </p>
    </AdminPanel>

    <AdminPanel v-if="can_import" title="Import">
      <div class="space-y-5 text-sm">
        <div class="grid gap-5 md:grid-cols-2">
          <div class="space-y-1.5">
            <Label for="import-package">Package</Label>
            <input
              id="import-package"
              type="file"
              accept=".zip,application/zip"
              class="block w-full text-sm file:me-3 file:rounded-md file:border file:border-gray-300 file:bg-white file:px-3 file:py-1.5 file:text-sm dark:file:border-gray-700 dark:file:bg-gray-900"
              @change="pick"
            />
          </div>
          <div class="space-y-1.5">
            <Label for="import-mode">What to do</Label>
            <Select v-model="form.mode">
              <SelectTrigger id="import-mode" class="w-full"><SelectValue /></SelectTrigger>
              <SelectContent>
                <SelectItem value="create">Add what's missing, leave the rest alone</SelectItem>
                <SelectItem value="update">Add what's missing and update what's there</SelectItem>
              </SelectContent>
            </Select>
          </div>
        </div>
        <label class="flex items-center gap-2.5">
          <Checkbox v-model="form.webhooks" />
          Tell webhooks about the changes
        </label>

        <div
          v-if="report"
          :class="[
            'rounded-lg px-4 py-3',
            report.ok ? 'bg-gray-50 dark:bg-gray-900' : 'bg-red-50 text-red-900 dark:bg-red-950/30 dark:text-red-200',
          ]"
        >
          <p v-if="report.ok" class="font-medium">{{ summary(report) }}</p>
          <template v-else>
            <p class="font-medium">Nothing was imported. The package has problems:</p>
            <ul class="mt-2 list-disc space-y-1 ps-5 font-mono text-xs">
              <li v-for="error in report.errors" :key="error">{{ error }}</li>
            </ul>
            <p v-if="report.more_errors" class="mt-2">and {{ report.more_errors }} more.</p>
          </template>
        </div>

        <div class="flex gap-2">
          <Button variant="outline" :disabled="!form.package || form.processing" @click="send(false)">
            Check package
          </Button>
          <Button :disabled="!form.package || !checked || form.processing" @click="importPackage">Import</Button>
        </div>
        <p class="text-gray-500">Checking writes nothing. Import stays off until a check comes back clean.</p>
      </div>
    </AdminPanel>
  </div>
</template>
