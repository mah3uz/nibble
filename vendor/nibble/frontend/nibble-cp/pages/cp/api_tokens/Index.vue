<script setup lang="ts">
import { router, useForm } from '@inertiajs/vue3'
import { ref, watch } from 'vue'
import CpIcon from '@/components/cp/icons/CpIcon.vue'
import DataTablePanel from '@/components/cp/page/DataTablePanel.vue'
import PageHeader from '@/components/cp/page/PageHeader.vue'
import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import { Checkbox } from '@/components/ui/checkbox'
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from '@/components/ui/dialog'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select'
import { useBreadcrumbs } from '@/lib/breadcrumbs'
import { useConfirm } from '@/lib/confirm'

type Token = {
  id: number
  name: string
  prefix: string
  scopes: string[]
  expires_at: string | null
  last_used_at: string | null
  created_by: string | null
  active: boolean
}

const props = defineProps<{
  tokens: Token[]
  scopes: { value: string; label: string }[]
  issued: { name: string; token: string } | null
}>()

const confirm = useConfirm()
const creating = ref(false)
const showIssued = ref(!!props.issued)

watch(
  () => props.issued,
  (issued) => (showIssued.value = !!issued),
)
watch(showIssued, (open) => {
  if (!open && props.issued) router.replaceProp('issued', null)
})

const form = useForm({ name: '', scopes: ['read'] as string[], expires_in: '90' })

const date = (value: string) => new Date(value).toLocaleDateString(undefined, { dateStyle: 'medium' })

const copyToken = () => navigator.clipboard.writeText(props.issued?.token ?? '')

function toggleScope(value: string, on: boolean) {
  form.scopes = on ? [...form.scopes, value] : form.scopes.filter((scope) => scope !== value)
}

async function create() {
  form
    .transform((data) => ({ api_token: data }))
    .post('/cp/api-tokens', {
      onSuccess: () => {
        creating.value = false
        form.reset()
      },
    })
}

async function revoke(token: Token) {
  const ok = await confirm({
    title: `Revoke ${token.name}?`,
    description: 'Anything using this token stops working at once.',
    confirmText: 'Revoke',
    dangerous: true,
  })
  if (ok) router.delete(`/cp/api-tokens/${token.id}`)
}

useBreadcrumbs([{ label: 'API tokens' }])
</script>

<template>
  <div class="mx-auto max-w-5xl">
    <div v-if="!tokens.length" class="mx-auto max-w-md py-14">
      <h1 class="mb-8 flex items-center justify-center gap-3 text-[25px] font-medium">
        <CpIcon name="key" class="size-5 text-gray-500" />API tokens
      </h1>
      <div class="rounded-2xl bg-gray-150 p-1.5 dark:bg-gray-950/35">
        <p class="px-4 pt-2 pb-3 text-sm">
          A token lets another site or app read this site's content through the API. Every request needs one.
        </p>
        <button
          type="button"
          class="flex w-full gap-4 rounded-xl bg-white p-5 text-start shadow-ui-sm hover:bg-gray-50 dark:bg-gray-900 dark:hover:bg-gray-850"
          @click="creating = true"
        >
          <CpIcon name="plus" class="mt-0.5 size-5 text-gray-500" />
          <span>
            <span class="block font-medium">Create a token</span>
            <span class="mt-1 block text-sm text-gray-600 dark:text-gray-400">
              Choose what it may read and when it expires.
            </span>
          </span>
        </button>
      </div>
    </div>

    <template v-else>
      <PageHeader title="API tokens" icon="key">
        <template #actions>
          <Button @click="creating = true">Create token</Button>
        </template>
      </PageHeader>
      <DataTablePanel>
        <thead>
          <tr>
            <th>Name</th>
            <th>Token</th>
            <th>Scopes</th>
            <th>Expires</th>
            <th>Last used</th>
            <th class="w-24"></th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="token in tokens" :key="token.id">
            <td>
              <span class="font-medium">{{ token.name }}</span>
              <span v-if="token.created_by" class="block text-xs text-gray-500">by {{ token.created_by }}</span>
            </td>
            <td class="font-mono text-xs">{{ token.prefix }}…</td>
            <td>
              <span class="flex flex-wrap gap-1">
                <Badge v-for="scope in token.scopes" :key="scope" variant="secondary">{{ scope }}</Badge>
              </span>
            </td>
            <td class="text-sm">{{ token.expires_at ? date(token.expires_at) : 'Never' }}</td>
            <td class="text-sm">{{ token.last_used_at ? date(token.last_used_at) : 'Never' }}</td>
            <td>
              <Button v-if="token.active" variant="outline" size="sm" @click="revoke(token)">Revoke</Button>
              <span v-else class="text-sm text-gray-500">Revoked</span>
            </td>
          </tr>
        </tbody>
      </DataTablePanel>
    </template>

    <Dialog v-model:open="creating">
      <DialogContent>
        <DialogHeader>
          <DialogTitle>Create API token</DialogTitle>
          <DialogDescription>The token is shown once, right after you create it.</DialogDescription>
        </DialogHeader>
        <form id="token-form" class="space-y-4" @submit.prevent="create">
          <div class="space-y-1.5">
            <Label for="token-name">Name</Label>
            <Input id="token-name" v-model="form.name" placeholder="Marketing site" required />
            <p v-if="form.errors.name" class="text-sm text-red-600">{{ form.errors.name }}</p>
          </div>
          <fieldset class="space-y-2">
            <legend class="text-sm font-medium">Scopes</legend>
            <label v-for="scope in scopes" :key="scope.value" class="flex items-center gap-2.5 text-sm">
              <Checkbox
                :model-value="form.scopes.includes(scope.value)"
                @update:model-value="(on) => toggleScope(scope.value, !!on)"
              />
              {{ scope.label }}
            </label>
            <p v-if="form.errors.scopes" class="text-sm text-red-600">{{ form.errors.scopes }}</p>
          </fieldset>
          <div class="space-y-1.5">
            <Label for="token-expiry">Expires</Label>
            <Select v-model="form.expires_in">
              <SelectTrigger id="token-expiry" class="w-full"><SelectValue /></SelectTrigger>
              <SelectContent>
                <SelectItem value="30">In 30 days</SelectItem>
                <SelectItem value="90">In 90 days</SelectItem>
                <SelectItem value="365">In a year</SelectItem>
                <SelectItem value="never">Never</SelectItem>
              </SelectContent>
            </Select>
          </div>
        </form>
        <DialogFooter show-close-button>
          <Button type="submit" form="token-form" :disabled="form.processing">Create</Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>

    <Dialog v-model:open="showIssued">
      <DialogContent @pointer-down-outside.prevent @interact-outside.prevent @escape-key-down.prevent>
        <DialogHeader>
          <DialogTitle>{{ issued?.name }}</DialogTitle>
          <DialogDescription>
            Copy it now. It isn't stored anywhere you can read it again, so a lost token has to be replaced.
          </DialogDescription>
        </DialogHeader>
        <code class="block rounded-lg bg-gray-100 px-3 py-2 font-mono text-sm break-all dark:bg-gray-900">
          {{ issued?.token }}
        </code>
        <DialogFooter show-close-button>
          <Button variant="outline" @click="copyToken">Copy</Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  </div>
</template>
