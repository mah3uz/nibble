<script setup lang="ts">
import { Link, router, useForm } from '@inertiajs/vue3'
import { Plug, Terminal } from '@lucide/vue'
import { computed, ref } from 'vue'
import ConnectionSettings, { type Connection } from '@/components/cp/agents/ConnectionSettings.vue'
import { connectionEnds, lastUsed, PRESET_LABELS } from '@/components/cp/agents/connection'
import CpPanel from '@/components/cp/page/CpPanel.vue'
import PageHeader from '@/components/cp/page/PageHeader.vue'
import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import { Switch } from '@/components/ui/switch'
import { useBreadcrumbs } from '@/lib/breadcrumbs'
import { useConfirm } from '@/lib/confirm'

type AreaRow = { key: string; title: string; group: string; values: Record<string, boolean> }
type GrantRow = Connection & { owner: { id: number; name: string; email: string }; created_at: string }

const props = defineProps<{
  enabled: boolean
  device_sign_in: boolean
  approvals: 'choose' | 'always'
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
  approvals: props.approvals,
  areas: Object.fromEntries(props.areas.map((area) => [area.key, { ...area.values }])) as Record<
    string,
    Record<string, boolean>
  >,
})
const groups = computed(() => [...new Set(props.areas.map((area) => area.group))])
const date = (value: string) => new Date(value).toLocaleDateString(undefined, { dateStyle: 'medium' })
const editing = ref<GrantRow | null>(null)
const settingsOpen = ref(false)
const APPROVALS = [
  {
    value: 'choose',
    label: 'Each person chooses',
    description:
      'When connecting an app, its person decides whether it asks before live changes or makes them without asking.',
  },
  {
    value: 'always',
    label: 'Always ask',
    description: 'Every app waits for approval before live changes, whatever its person chose.',
  },
]

function edit(grant: GrantRow) {
  editing.value = grant
  settingsOpen.value = true
}

const save = () => form.patch('/cp/agent-access', { preserveScroll: true })

async function revoke(grant: GrantRow) {
  const ok = await confirm({
    title: `Disconnect ${grant.name} for ${grant.owner.name}?`,
    description: 'It stops working at once. They can connect it again if their role allows.',
    confirmText: 'Disconnect',
    dangerous: true,
  })
  if (ok) router.delete(`/cp/agent-access/grants/${grant.id}`, { preserveScroll: true })
}

useBreadcrumbs([{ label: 'Agent access' }])
</script>

<template>
  <div class="mx-auto max-w-7xl">
    <PageHeader title="Agent access" icon="arrow-roadmap-path-flow">
      <template #actions>
        <Button :disabled="form.processing || !form.isDirty" @click="save">Save</Button>
      </template>
    </PageHeader>

    <div class="grid gap-8 xl:grid-cols-[1fr_340px]">
      <div class="min-w-0">
        <CpPanel>
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
          <label class="flex items-start justify-between gap-6 pt-3">
            <span>
              <span class="block font-medium">Allow signing in with a code</span>
              <span class="block text-sm text-gray-600 dark:text-gray-400">
                For apps on a server or another computer without a browser. Codes can be phished, so leave this off
                unless someone needs it.
              </span>
            </span>
            <Switch v-model="form.device_sign_in" :disabled="!form.enabled" />
          </label>
          <div v-if="enabled" class="mt-3 rounded-lg bg-gray-50 p-3 text-sm dark:bg-gray-900">
            <p>
              Apps connect to <code class="font-mono">{{ endpoints.mcp }}</code>
            </p>
            <p class="mt-1 text-gray-600 dark:text-gray-400">
              People with these roles can connect apps: {{ roles.length ? roles.join(', ') : 'none' }}.
              <Link href="/cp/roles" class="underline">Change it in Roles</Link> with the “Connect apps” permission.
            </p>
          </div>
        </CpPanel>

        <CpPanel title="Approvals" description="Whether apps wait for a person before changes that go live.">
          <fieldset class="space-y-2" :disabled="!form.enabled">
            <legend class="sr-only">Approvals</legend>
            <label
              v-for="option in APPROVALS"
              :key="option.value"
              class="flex gap-3 rounded-lg border p-3 text-sm has-checked:border-gray-900 has-disabled:opacity-50 dark:has-checked:border-white"
            >
              <input
                v-model="form.approvals"
                type="radio"
                name="approvals"
                :value="option.value"
                class="mt-0.5 accent-gray-900 dark:accent-white"
              />
              <span>
                <span class="block font-medium">{{ option.label }}</span>
                <span class="block text-gray-600 dark:text-gray-400">{{ option.description }}</span>
              </span>
            </label>
          </fieldset>
          <p class="text-sm text-gray-600 dark:text-gray-400">
            An app signed in with a code always asks. Tokens for scripts never do: nobody is there to approve.
          </p>
        </CpPanel>

        <CpPanel
          v-for="group in groups"
          :key="group"
          :title="group"
          description="What connected apps may do. Each person's own role still applies."
          flush
        >
          <div class="overflow-x-auto">
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
      </div>

      <aside class="self-start">
        <CpPanel
          title="Connected apps"
          :description="grants.length ? `${grants.length} on this site` : undefined"
          flush
        >
          <div v-if="!grants.length" class="flex flex-col items-center gap-2 px-6 py-10 text-center">
            <Plug class="size-5 text-gray-400" />
            <p class="text-sm text-gray-600 dark:text-gray-400">No apps are connected.</p>
            <p class="text-xs text-gray-500">People connect them from their account menu, under Connected apps.</p>
          </div>
          <ul v-else class="divide-y divide-gray-100 dark:divide-gray-800" role="list">
            <li v-for="grant in grants" :key="grant.id" class="space-y-2.5 p-4">
              <div class="flex items-start gap-3">
                <span
                  class="flex size-8 shrink-0 items-center justify-center rounded-lg bg-gray-100 text-gray-600 dark:bg-white/7 dark:text-gray-300"
                >
                  <Terminal v-if="grant.kind === 'ci'" class="size-4" />
                  <Plug v-else class="size-4" />
                </span>
                <div class="min-w-0 flex-1">
                  <p class="truncate font-medium text-gray-900 dark:text-gray-100" :title="grant.name">
                    {{ grant.name }}
                  </p>
                  <p class="truncate text-sm text-gray-600 dark:text-gray-400" :title="grant.owner.email">
                    {{ grant.owner.name }}
                  </p>
                  <div class="mt-1.5 flex flex-wrap gap-1.5">
                    <Badge variant="secondary">{{ PRESET_LABELS[grant.preset] ?? grant.preset }}</Badge>
                    <Badge variant="secondary">{{ grant.asks_approval ? 'Asks first' : "Doesn't ask" }}</Badge>
                  </div>
                </div>
              </div>
              <dl class="grid grid-cols-[auto_1fr] gap-x-3 gap-y-1 text-xs">
                <dt class="text-gray-500">Last used</dt>
                <dd class="text-gray-700 dark:text-gray-300">
                  <time v-if="grant.last_used_at" :datetime="grant.last_used_at" :title="date(grant.last_used_at)">{{
                    lastUsed(grant)
                  }}</time>
                  <template v-else>Never</template>
                </dd>
                <dt class="text-gray-500">Ends</dt>
                <dd class="text-gray-700 dark:text-gray-300">
                  <time :datetime="grant.expires_at" :title="date(grant.expires_at)">{{ connectionEnds(grant) }}</time>
                </dd>
              </dl>
              <div class="grid grid-cols-2 gap-2">
                <Button variant="outline" size="sm" @click="edit(grant)">Settings</Button>
                <Button variant="outline" size="sm" @click="revoke(grant)">Disconnect</Button>
              </div>
            </li>
          </ul>
        </CpPanel>
      </aside>
    </div>

    <ConnectionSettings
      v-model:open="settingsOpen"
      :connection="editing"
      url="/cp/agent-access/grants"
      :site-approvals="approvals"
      elevated
    />
  </div>
</template>
