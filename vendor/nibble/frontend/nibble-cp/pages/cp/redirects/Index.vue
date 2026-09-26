<script setup lang="ts">
import { router, useForm, usePage } from '@inertiajs/vue3'
import { ref } from 'vue'
import DataTablePanel from '@/components/cp/page/DataTablePanel.vue'
import PageHeader from '@/components/cp/page/PageHeader.vue'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select'
import { useConfirm } from '@/lib/confirm'

type Redirect = {
  id: number
  from: string
  to: string
  status: number
  source: string
  hits: number
  last_hit_at: string | null
}

const props = defineProps<{ redirects: Redirect[]; statuses: number[] }>()
const page = usePage<{ errors: Record<string, string> }>()
const confirm = useConfirm()
const editing = ref<Redirect | null>(null)

const form = useForm({
  from: new URLSearchParams(window.location.search).get('from') ?? '',
  to: '',
  status: 301,
})

function edit(redirect: Redirect) {
  editing.value = redirect
  form.from = redirect.from
  form.to = redirect.to
  form.status = redirect.status
}

function submit() {
  if (editing.value) form.transform((data) => ({ redirect: data })).patch(`/cp/redirects/${editing.value.id}`)
  else form.transform((data) => ({ redirect: data })).post('/cp/redirects')
  editing.value = null
  form.reset()
}

async function remove(redirect: Redirect) {
  const ok = await confirm({
    title: `Delete the redirect from ${redirect.from}?`,
    confirmText: 'Delete',
    dangerous: true,
  })
  if (ok) router.delete(`/cp/redirects/${redirect.id}`)
}
</script>

<template>
  <div class="mx-auto max-w-5xl">
    <PageHeader title="Redirects" icon="arrow-roadmap-path-flow" :breadcrumbs="[{ label: 'Redirects' }]" />

    <form
      class="relative mb-8 w-full rounded-2xl bg-gray-150 p-1.75 dark:bg-gray-950/35 dark:inset-shadow-2xs dark:inset-shadow-black"
      @submit.prevent="submit"
    >
      <div
        class="grid gap-4 rounded-xl bg-white px-4 py-5 shadow-ui-md ring ring-gray-200 sm:px-4.5 md:grid-cols-[1fr_1fr_8rem_auto] dark:bg-gray-850 dark:ring-gray-700/80"
      >
        <div class="space-y-1.5">
          <Label for="from">From</Label>
          <Input id="from" v-model="form.from" placeholder="/old-path" :aria-invalid="!!page.props.errors?.from" />
        </div>
        <div class="space-y-1.5">
          <Label for="to">To</Label>
          <Input id="to" v-model="form.to" placeholder="/new-path" :aria-invalid="!!page.props.errors?.to" />
        </div>
        <div class="space-y-1.5">
          <Label for="status">Status</Label>
          <Select v-model="form.status">
            <SelectTrigger id="status" class="w-full"><SelectValue /></SelectTrigger>
            <SelectContent>
              <SelectItem v-for="status in props.statuses" :key="status" :value="status">{{ status }}</SelectItem>
            </SelectContent>
          </Select>
        </div>
        <div class="flex items-end">
          <Button type="submit">{{ editing ? 'Save' : 'Add redirect' }}</Button>
        </div>
        <p v-if="page.props.errors?.from" class="text-sm text-destructive md:col-span-4">
          {{ page.props.errors.from }}
        </p>
        <p v-if="page.props.errors?.to" class="text-sm text-destructive md:col-span-4">{{ page.props.errors.to }}</p>
      </div>
    </form>

    <DataTablePanel>
      <thead>
        <tr>
          <th>From</th>
          <th>To</th>
          <th class="w-24">Status</th>
          <th class="w-24">Hits</th>
          <th class="actions-column" />
        </tr>
      </thead>
      <tbody>
        <tr v-for="redirect in redirects" :key="redirect.id">
          <td class="font-mono text-sm">{{ redirect.from }}</td>
          <td class="font-mono text-sm">{{ redirect.to }}</td>
          <td class="text-sm">{{ redirect.status }}</td>
          <td class="text-sm text-gray-600 dark:text-gray-400">{{ redirect.hits }}</td>
          <td class="actions-column">
            <div class="flex justify-end gap-1">
              <Button variant="ghost" size="sm" @click="edit(redirect)">Edit</Button>
              <Button variant="ghost" size="sm" class="text-destructive" @click="remove(redirect)">Delete</Button>
            </div>
          </td>
        </tr>
        <tr v-if="!redirects.length">
          <td colspan="5" class="py-8! text-center text-gray-500!">
            No redirects yet. Changing a page's URL adds one automatically.
          </td>
        </tr>
      </tbody>
    </DataTablePanel>
  </div>
</template>
