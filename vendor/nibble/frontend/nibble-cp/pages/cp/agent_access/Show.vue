<script setup lang="ts">
import { Link, router, useForm } from '@inertiajs/vue3'
import { computed } from 'vue'
import CpPanel from '@/components/cp/page/CpPanel.vue'
import DataTablePanel from '@/components/cp/page/DataTablePanel.vue'
import PageHeader from '@/components/cp/page/PageHeader.vue'
import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import { Switch } from '@/components/ui/switch'
import { useBreadcrumbs } from '@/lib/breadcrumbs'
import { useConfirm } from '@/lib/confirm'

type AreaRow = { key: string; title: string; group: string; values: Record<string, boolean> }
type GrantRow = {
  id: number
  name: string
  kind: string
  preset: string
  via: string | null
  person: string
  email: string
  created_at: string
  last_used_at: string | null
  last_used_ip: string | null
  expires_at: string
}

const props = defineProps<{
  enabled: boolean
  device_sign_in: boolean
  areas: AreaRow[]
  columns: { value: string; label: string }[]
  roles: string[]
  grants: GrantRow[]
  endpoints: { mcp: string; api: string }
}>()

const confirm = useConfirm()
const form = useForm({
  enabled: props.enabled,
  device_sign_in: props.device_sign_in,
  areas: Object.fromEntries(props.areas.map((area) => [area.key, { ...area.values }])) as Record<
    string,
    Record<string, boolean>
  >,
})
const groups = computed(() => [...new Set(props.areas.map((area) => area.group))])
const date = (value: string) => new Date(value).toLocaleDateString(undefined, { dateStyle: 'medium' })

const save = () => form.patch('/cp/agent-access', { preserveScroll: true })

async function revoke(grant: GrantRow) {
  const ok = await confirm({
    title: `Disconnect ${grant.name} for ${grant.person}?`,
    description: 'It stops working at once. They can connect it again if their role allows.',
    confirmText: 'Disconnect',
    dangerous: true,
  })
  if (ok) router.delete(`/cp/agent-access/grants/${grant.id}`, { preserveScroll: true })
}

useBreadcrumbs([{ label: 'Agent access' }])
</script>

<template>
  <div class="mx-auto max-w-5xl">
    <PageHeader title="Agent access" icon="arrow-roadmap-path-flow">
      <template #actions>
        <Button :disabled="form.processing || !form.isDirty" @click="save">Save</Button>
      </template>
    </PageHeader>

    <CpPanel>
      <div class="space-y-4 rounded-xl bg-white p-5 shadow-ui-sm dark:bg-gray-900">
        <label class="flex items-start justify-between gap-6">
          <span>
            <span class="block font-medium">Let people connect AI apps</span>
            <span class="block text-sm text-gray-600 dark:text-gray-400">
              Claude, ChatGPT, Codex, Cursor and the nibble CLI can then work on content as the person who connected
              them, never doing more than that person can, and only what this page allows.
            </span>
          </span>
          <Switch v-model="form.enabled" />
        </label>
        <label class="flex items-start justify-between gap-6">
          <span>
            <span class="block font-medium">Allow signing in with a code</span>
            <span class="block text-sm text-gray-600 dark:text-gray-400">
              For apps on a server or another computer without a browser. Codes can be phished, so leave this off unless
              someone needs it.
            </span>
          </span>
          <Switch v-model="form.device_sign_in" :disabled="!form.enabled" />
        </label>
        <div v-if="enabled" class="rounded-lg bg-gray-50 p-3 text-sm dark:bg-gray-850">
          <p>
            Apps connect to <code class="font-mono">{{ endpoints.mcp }}</code>
          </p>
          <p class="mt-1 text-gray-600 dark:text-gray-400">
            People with these roles can connect apps: {{ roles.length ? roles.join(', ') : 'none' }}.
            <Link href="/cp/roles" class="underline">Change it in Roles</Link> with the “Connect apps” permission.
          </p>
        </div>
      </div>
    </CpPanel>

    <CpPanel
      v-for="group in groups"
      :key="group"
      :title="group"
      description="What connected apps may do. Each person's own role still applies."
    >
      <div class="overflow-x-auto rounded-xl bg-white shadow-ui-sm dark:bg-gray-900">
        <table class="w-full text-sm">
          <thead>
            <tr class="text-left text-gray-600 dark:text-gray-400">
              <th class="px-4 py-2.5 font-medium"></th>
              <th v-for="column in columns" :key="column.value" class="w-24 px-4 py-2.5 text-center font-medium">
                {{ column.label }}
              </th>
            </tr>
          </thead>
          <tbody>
            <tr
              v-for="area in areas.filter((item) => item.group === group)"
              :key="area.key"
              class="border-t border-gray-100 dark:border-gray-800"
            >
              <td class="px-4 py-2.5 font-medium">{{ area.title }}</td>
              <td v-for="column in columns" :key="column.value" class="px-4 py-2.5 text-center">
                <Switch
                  v-if="column.value in area.values"
                  v-model="form.areas[area.key][column.value]"
                  :disabled="!form.enabled"
                  :aria-label="`${column.label} ${area.title}`"
                />
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </CpPanel>

    <h2 class="mt-2 mb-3 text-sm font-medium">Connected apps on this site</h2>
    <p v-if="!grants.length" class="text-sm text-gray-600 dark:text-gray-400">Nobody has connected an app.</p>
    <DataTablePanel v-else>
      <thead>
        <tr>
          <th>App</th>
          <th>Person</th>
          <th>Access</th>
          <th>Last used</th>
          <th>Expires</th>
          <th class="w-28"></th>
        </tr>
      </thead>
      <tbody>
        <tr v-for="grant in grants" :key="grant.id">
          <td class="font-medium">{{ grant.name }}</td>
          <td>
            {{ grant.person }}<span class="block text-xs text-gray-500">{{ grant.email }}</span>
          </td>
          <td>
            <Badge variant="secondary">{{ grant.preset }}</Badge>
          </td>
          <td class="text-sm">
            {{ grant.last_used_at ? date(grant.last_used_at) : 'Never' }}
            <span v-if="grant.last_used_ip" class="block text-xs text-gray-500">{{ grant.last_used_ip }}</span>
          </td>
          <td class="text-sm">{{ date(grant.expires_at) }}</td>
          <td><Button variant="outline" size="sm" @click="revoke(grant)">Disconnect</Button></td>
        </tr>
      </tbody>
    </DataTablePanel>
  </div>
</template>
