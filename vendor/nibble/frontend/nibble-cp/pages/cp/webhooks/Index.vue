<script setup lang="ts">
import { Link, router } from '@inertiajs/vue3'
import CpIcon from '@/components/cp/icons/CpIcon.vue'
import StatusCell from '@/components/cp/listing/cells/StatusCell.vue'
import DataTablePanel from '@/components/cp/page/DataTablePanel.vue'
import PageHeader from '@/components/cp/page/PageHeader.vue'
import { Button } from '@/components/ui/button'
import { useBreadcrumbs } from '@/lib/breadcrumbs'

type WebhookRow = {
  id: number
  name: string
  url: string
  events: string[]
  enabled: boolean
  disabled_reason: string | null
  edit_url: string
  last_delivery: { status: string; at: string } | null
}

defineProps<{ webhooks: WebhookRow[] }>()

const date = (value: string) => new Date(value).toLocaleString(undefined, { dateStyle: 'medium', timeStyle: 'short' })

useBreadcrumbs([{ label: 'Webhooks' }])
</script>

<template>
  <div class="mx-auto max-w-5xl">
    <div v-if="!webhooks.length" class="mx-auto max-w-md py-14">
      <h1 class="mb-8 flex items-center justify-center gap-3 text-[25px] font-medium">
        <CpIcon name="webhooks" class="size-5 text-gray-500" />Webhooks
      </h1>
      <div class="rounded-2xl bg-gray-150 p-1.5 dark:bg-gray-950/35">
        <p class="px-4 pt-2 pb-3 text-sm">
          Webhooks tell other systems when content changes or a form is submitted, by sending a signed request to their
          URL.
        </p>
        <Link
          href="/cp/webhooks/new"
          class="flex gap-4 rounded-xl bg-white p-5 shadow-ui-sm hover:bg-gray-50 dark:bg-gray-900 dark:hover:bg-gray-850"
        >
          <CpIcon name="plus" class="mt-0.5 size-5 text-gray-500" />
          <div>
            <p class="font-medium">Create a webhook</p>
            <p class="mt-1 text-sm text-gray-600 dark:text-gray-400">
              Choose the events to send and where to send them.
            </p>
          </div>
        </Link>
      </div>
    </div>

    <template v-else>
      <PageHeader title="Webhooks" icon="webhooks">
        <template #actions>
          <Button as-child><Link href="/cp/webhooks/new">Create webhook</Link></Button>
        </template>
      </PageHeader>
      <DataTablePanel>
        <thead>
          <tr>
            <th>Name</th>
            <th>Events</th>
            <th>Last delivery</th>
            <th class="w-28">Status</th>
          </tr>
        </thead>
        <tbody>
          <tr
            v-for="webhook in webhooks"
            :key="webhook.id"
            class="cursor-pointer"
            @click="router.visit(webhook.edit_url)"
          >
            <td>
              <Link :href="webhook.edit_url" class="font-medium hover:underline">{{ webhook.name }}</Link>
              <span class="block truncate text-xs text-gray-500">{{ webhook.url }}</span>
            </td>
            <td class="text-sm">{{ webhook.events.length }}</td>
            <td class="text-sm">
              <template v-if="webhook.last_delivery">
                <StatusCell :value="webhook.last_delivery.status" />
                <span class="ms-2 text-gray-500">{{ date(webhook.last_delivery.at) }}</span>
              </template>
              <span v-else class="text-gray-500">Never</span>
            </td>
            <td>
              <StatusCell :value="webhook.enabled ? 'enabled' : 'disabled'" />
            </td>
          </tr>
        </tbody>
      </DataTablePanel>
    </template>
  </div>
</template>
