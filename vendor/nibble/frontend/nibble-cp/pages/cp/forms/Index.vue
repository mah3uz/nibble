<script setup lang="ts">
import { Link, router } from '@inertiajs/vue3'
import CpIcon from '@/components/cp/icons/CpIcon.vue'
import DataTablePanel from '@/components/cp/page/DataTablePanel.vue'
import PageHeader from '@/components/cp/page/PageHeader.vue'
import { useBreadcrumbs } from '@/lib/breadcrumbs'

type FormRow = { handle: string; title: string; submissions: number; unread: number; store: boolean; url: string }

defineProps<{ forms: FormRow[] }>()

useBreadcrumbs([{ label: 'Forms' }])
</script>

<template>
  <div class="mx-auto max-w-5xl">
    <div v-if="!forms.length" class="mx-auto max-w-md py-14">
      <h1 class="mb-8 flex items-center justify-center gap-3 text-[25px] font-medium">
        <CpIcon name="forms" class="size-5 text-gray-500" />Forms
      </h1>
      <div class="rounded-2xl bg-gray-150 p-1.5 dark:bg-gray-950/35">
        <p class="px-4 pt-2 pb-3 text-sm">
          Forms collect information from visitors and can trigger notifications and deliveries when submissions are
          received.
        </p>
        <div class="space-y-6 rounded-xl bg-white p-5 shadow-ui-sm dark:bg-gray-900">
          <div class="flex gap-4">
            <CpIcon name="forms" class="mt-0.5 size-5 text-gray-500" />
            <div>
              <p class="font-medium">Define a form</p>
              <p class="mt-1 text-sm text-gray-600 dark:text-gray-400">
                Add a file to <code>schema/forms</code> with its fields, spam protection and notifications.
              </p>
            </div>
          </div>
          <div class="flex gap-4">
            <CpIcon name="globals" class="mt-0.5 size-5 text-gray-500" />
            <div>
              <Link href="/cp/globals/integrations/edit" class="font-medium hover:underline">Configure email</Link>
              <p class="mt-1 text-sm text-gray-600 dark:text-gray-400">
                Set the sender address so notifications about new submissions can be sent.
              </p>
            </div>
          </div>
        </div>
      </div>
    </div>

    <template v-else>
      <PageHeader title="Forms" icon="forms" />
      <DataTablePanel>
        <thead>
          <tr>
            <th>Title</th>
            <th class="w-40">Submissions</th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="form in forms" :key="form.handle" class="cursor-pointer" @click="router.visit(form.url)">
            <td>
              <Link :href="form.url" class="font-medium hover:underline">{{ form.title }}</Link>
              <span v-if="!form.store" class="ms-2 text-xs text-gray-500">Not stored</span>
            </td>
            <td>
              {{ form.submissions }}
              <span
                v-if="form.unread"
                class="ms-2 inline-block rounded-full bg-blue-100 px-2 py-0.5 text-xs text-blue-900 dark:bg-blue-300/10 dark:text-blue-300"
                >{{ form.unread }} new</span
              >
            </td>
          </tr>
        </tbody>
      </DataTablePanel>
    </template>
  </div>
</template>
