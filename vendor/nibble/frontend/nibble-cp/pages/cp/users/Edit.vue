<script setup lang="ts">
import { Link, router, useForm } from '@inertiajs/vue3'
import CpIcon from '@/components/cp/icons/CpIcon.vue'
import PageHeader from '@/components/cp/page/PageHeader.vue'
import { Button } from '@/components/ui/button'
import { Checkbox } from '@/components/ui/checkbox'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { useConfirm } from '@/lib/confirm'

type RoleOption = { id: number; title: string; superuser: boolean }
type SessionRow = {
  id: number
  user_agent: string | null
  ip_address: string | null
  created_at: string
  current: boolean
}

const props = defineProps<{
  user: { id: number; name: string; email_address: string; role_ids: number[]; last_login_at: string | null }
  roles: RoleOption[]
  self: boolean
  sessions: SessionRow[]
}>()

const confirm = useConfirm()
const form = useForm({
  name: props.user.name,
  email_address: props.user.email_address,
  role_ids: [...props.user.role_ids],
})

const date = (value: string) => new Date(value).toLocaleString(undefined, { dateStyle: 'medium', timeStyle: 'short' })

function toggleRole(id: number, on: boolean) {
  form.role_ids = on ? [...form.role_ids, id] : form.role_ids.filter((value) => value !== id)
}

async function save() {
  form.transform((data) => ({ user: data })).patch(`/cp/users/${props.user.id}`)
}

async function sendReset() {
  router.post(`/cp/users/${props.user.id}/send_reset`)
}

async function destroy() {
  const ok = await confirm({
    title: `Delete ${props.user.name}?`,
    description: 'Their sessions end at once. Content they wrote stays.',
    confirmText: 'Delete',
    dangerous: true,
  })
  if (ok) router.delete(`/cp/users/${props.user.id}`)
}

async function revoke(session: SessionRow) {
  const ok = await confirm({
    title: 'Revoke this session?',
    description: 'That browser is signed out immediately.',
    confirmText: 'Revoke',
    dangerous: true,
  })
  if (ok) router.delete(`/cp/users/${props.user.id}/sessions/${session.id}`)
}
</script>

<template>
  <div class="mx-auto max-w-5xl">
    <Link
      href="/cp/users"
      class="relative z-10 -mb-6 flex w-fit items-center gap-1 pt-6 text-sm text-gray-600 hover:text-gray-900 dark:text-gray-400 dark:hover:text-white"
    >
      <CpIcon name="chevron-left" class="size-4" />Users
    </Link>
    <PageHeader
      :title="user.name"
      icon="users"
      :breadcrumbs="[{ label: 'Users', url: '/cp/users' }, { label: user.name }]"
    >
      <template #actions>
        <Button v-if="!self" variant="outline" @click="destroy">Delete</Button>
        <Button variant="outline" @click="sendReset"> Send password reset </Button>
        <Button :disabled="form.processing" @click="save">Save</Button>
      </template>
    </PageHeader>

    <form class="mb-6 rounded-2xl bg-gray-150 p-1.75 dark:bg-gray-950/35" @submit.prevent="save">
      <p class="px-3 pt-1.5 pb-2.5 text-sm font-medium text-gray-700 dark:text-gray-300">Account</p>
      <div
        class="space-y-6 rounded-xl bg-white px-4 py-5 shadow-ui-md ring ring-gray-200 dark:bg-gray-850 dark:ring-gray-700/80"
      >
        <div class="grid gap-6 md:grid-cols-2">
          <div class="space-y-1.5">
            <Label for="user-name">Name</Label>
            <Input id="user-name" v-model="form.name" :aria-invalid="!!form.errors.name" />
            <p v-if="form.errors.name" class="text-sm text-red-600">{{ form.errors.name }}</p>
          </div>
          <div class="space-y-1.5">
            <Label for="user-email">Email</Label>
            <Input
              id="user-email"
              v-model="form.email_address"
              type="email"
              :aria-invalid="!!form.errors.email_address"
            />
            <p v-if="form.errors.email_address" class="text-sm text-red-600">{{ form.errors.email_address }}</p>
          </div>
        </div>
        <fieldset class="space-y-2">
          <legend class="text-sm font-medium">Roles</legend>
          <p v-if="self" class="text-sm text-gray-600 dark:text-gray-400">
            You can't change your own roles. Ask another administrator.
          </p>
          <label v-for="role in roles" :key="role.id" class="flex items-center gap-2.5 text-sm">
            <Checkbox
              :model-value="form.role_ids.includes(role.id)"
              :disabled="self"
              @update:model-value="(on) => toggleRole(role.id, !!on)"
            />
            {{ role.title }}
            <span v-if="role.superuser" class="text-gray-500">— full access</span>
          </label>
        </fieldset>
        <p class="text-sm text-gray-600 dark:text-gray-400">
          Last sign-in: {{ user.last_login_at ? date(user.last_login_at) : 'never' }}
        </p>
      </div>
    </form>

    <div class="rounded-2xl bg-gray-150 p-1.75 dark:bg-gray-950/35">
      <p class="px-3 pt-1.5 pb-2.5 text-sm font-medium text-gray-700 dark:text-gray-300">Sessions</p>
      <div class="rounded-xl bg-white px-4 py-2 shadow-ui-md ring ring-gray-200 dark:bg-gray-850 dark:ring-gray-700/80">
        <ul v-if="sessions.length" class="divide-y divide-gray-200 dark:divide-gray-700/80">
          <li v-for="session in sessions" :key="session.id" class="flex items-center justify-between gap-3 py-3">
            <div class="min-w-0">
              <p class="truncate text-sm font-medium">
                {{ session.user_agent || 'Unknown device' }}
                <span v-if="session.current" class="text-gray-500">(this session)</span>
              </p>
              <p class="text-xs text-gray-500">
                {{ session.ip_address || 'Unknown IP' }} · Signed in {{ date(session.created_at) }}
              </p>
            </div>
            <Button variant="outline" size="sm" @click="revoke(session)">Revoke</Button>
          </li>
        </ul>
        <p v-else class="py-3 text-sm text-gray-500">No active sessions.</p>
      </div>
    </div>
  </div>
</template>
