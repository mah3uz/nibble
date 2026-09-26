<script setup lang="ts">
import { Link, router, useForm } from '@inertiajs/vue3'
import { computed } from 'vue'
import CpIcon from '@/components/cp/icons/CpIcon.vue'
import PermissionNode from '@/components/cp/roles/PermissionNode.vue'
import PageHeader from '@/components/cp/page/PageHeader.vue'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Switch } from '@/components/ui/switch'
import { useConfirm } from '@/lib/confirm'

type Node = { value: string; title: string; description: string | null; children: Node[] }
type Group = { handle: string; title: string; abilities: Node[] }

const props = defineProps<{
  role: {
    id: number | null
    title: string
    handle: string
    superuser: boolean
    require_2fa: boolean
    abilities: string[]
    users: number
  }
  groups: Group[]
  can_assign_superuser: boolean
}>()

const confirm = useConfirm()
const base = computed(() => (props.role.id ? `/cp/roles/${props.role.id}` : null))
const title = computed(() => (props.role.id ? props.role.title : 'Create role'))

const form = useForm({
  title: props.role.title,
  handle: props.role.handle,
  superuser: props.role.superuser,
  require_2fa: props.role.require_2fa,
  abilities: [...props.role.abilities],
})

const descend = (nodes: Node[]): Node[] => nodes.flatMap((node) => [node, ...descend(node.children)])
const wildcardOf = (group: Group) => group.abilities.find((node) => node.value.endsWith('.*'))?.value

function parentsOf(group: Group, value: string, trail: string[] = []): string[] | null {
  for (const node of group.abilities.length ? group.abilities : []) {
    const found = search(node, value, trail)
    if (found) return found
  }
  return null
}

function search(node: Node, value: string, trail: string[]): string[] | null {
  if (node.value === value) return trail
  for (const child of node.children) {
    const found = search(child, value, [...trail, node.value])
    if (found) return found
  }
  return null
}

const held = (value: string) => form.abilities.includes(value)

function covered(group: Group, value: string) {
  const wildcard = wildcardOf(group)
  return held(value) || (!!wildcard && wildcard !== value && held(wildcard))
}

function locked(group: Group, value: string) {
  const wildcard = wildcardOf(group)
  return !!wildcard && wildcard !== value && held(wildcard)
}

function set(values: string[], on: boolean) {
  const next = new Set(form.abilities)
  values.forEach((value) => (on ? next.add(value) : next.delete(value)))
  form.abilities = [...next]
}

function toggle(group: Group, node: Node, on: boolean) {
  if (on) {
    set([node.value, ...(parentsOf(group, node.value) ?? [])], true)
  } else {
    set([node.value, ...descend(node.children).map((child) => child.value)], false)
  }
}

const allValues = computed(() => props.groups.flatMap((group) => descend(group.abilities).map((node) => node.value)))
const allChecked = computed(() => allValues.value.every((value) => held(value)))

const checkAll = () => set(allValues.value, !allChecked.value)

function checkGroup(group: Group) {
  const values = descend(group.abilities).map((node) => node.value)
  set(values, !values.every((value) => held(value)))
}

async function save() {
  const request = form.transform((data) => ({ role: data }))
  if (base.value) request.patch(base.value, { preserveScroll: true })
  else request.post('/cp/roles')
}

async function destroy() {
  const ok = await confirm({
    title: `Delete ${props.role.title}?`,
    description: props.role.users
      ? `${props.role.users} ${props.role.users === 1 ? 'person holds' : 'people hold'} this role and will lose it.`
      : 'Nobody holds this role.',
    confirmText: 'Delete',
    dangerous: true,
  })
  if (ok) router.delete(base.value!)
}
</script>

<template>
  <div class="mx-auto max-w-5xl">
    <Link
      href="/cp/roles"
      class="relative z-10 -mb-6 flex w-fit items-center gap-1 pt-6 text-sm text-gray-600 hover:text-gray-900 dark:text-gray-400 dark:hover:text-white"
    >
      <CpIcon name="chevron-left" class="size-4" />Roles
    </Link>
    <PageHeader :title="title" icon="users" :breadcrumbs="[{ label: 'Roles', url: '/cp/roles' }, { label: title }]">
      <template #actions>
        <Button v-if="role.id" variant="outline" @click="destroy">Delete</Button>
        <Button v-if="!form.superuser" variant="outline" @click="checkAll">
          {{ allChecked ? 'Uncheck all' : 'Check all' }}
        </Button>
        <Button :disabled="form.processing" @click="save">{{ role.id ? 'Save' : 'Create' }}</Button>
      </template>
    </PageHeader>

    <form @submit.prevent="save">
      <div class="mb-6 rounded-2xl bg-gray-150 p-1.75 dark:bg-gray-950/35">
        <p class="px-3 pt-1.5 pb-2.5 text-sm font-medium text-gray-700 dark:text-gray-300">Settings</p>
        <div
          class="divide-y divide-gray-200 rounded-xl bg-white shadow-ui-md ring ring-gray-200 dark:divide-gray-700/80 dark:bg-gray-850 dark:ring-gray-700/80"
        >
          <div class="grid gap-3 px-4 py-4 md:grid-cols-2 md:items-center">
            <div>
              <Label for="role-title">Title</Label>
              <p class="mt-1 text-sm text-gray-600 dark:text-gray-400">
                Use a singular noun, such as 'Editor' or 'Author'.
              </p>
            </div>
            <div class="space-y-1.5">
              <Input id="role-title" v-model="form.title" :aria-invalid="!!form.errors.title" />
              <p v-if="form.errors.title" class="text-sm text-red-600">{{ form.errors.title }}</p>
            </div>
          </div>
          <div class="grid gap-3 px-4 py-4 md:grid-cols-2 md:items-center">
            <div>
              <Label for="role-handle">Handle</Label>
              <p class="mt-1 text-sm text-gray-600 dark:text-gray-400">
                The identifier used in code. Left blank, it follows the title.
              </p>
            </div>
            <div class="space-y-1.5">
              <Input id="role-handle" v-model="form.handle" :aria-invalid="!!form.errors.handle" />
              <p v-if="form.errors.handle" class="text-sm text-red-600">{{ form.errors.handle }}</p>
            </div>
          </div>
          <div v-if="can_assign_superuser" class="grid gap-3 px-4 py-4 md:grid-cols-2 md:items-center">
            <div>
              <Label for="role-superuser">Full access</Label>
              <p class="mt-1 text-sm text-gray-600 dark:text-gray-400">
                Everything in the Control Plane, including anything added later. Grant it sparingly.
              </p>
            </div>
            <div class="space-y-1.5">
              <Switch id="role-superuser" v-model="form.superuser" />
              <p v-if="form.errors.superuser" class="text-sm text-red-600">{{ form.errors.superuser }}</p>
            </div>
          </div>
          <div class="grid gap-3 px-4 py-4 md:grid-cols-2 md:items-center">
            <div>
              <Label for="role-2fa">Require two-factor authentication</Label>
              <p class="mt-1 text-sm text-gray-600 dark:text-gray-400">
                People holding this role must set up an authenticator app or a passkey before they can work.
              </p>
            </div>
            <Switch id="role-2fa" v-model="form.require_2fa" />
          </div>
        </div>
      </div>

      <p v-if="form.superuser" class="rounded-xl bg-gray-100 px-4 py-3 text-sm dark:bg-gray-900">
        This role grants everything, so there is nothing to choose.
      </p>

      <div
        v-for="group in groups"
        v-else
        :key="group.handle"
        class="mb-6 rounded-2xl bg-gray-150 p-1.75 dark:bg-gray-950/35"
      >
        <div class="flex items-center justify-between px-3 pt-1.5 pb-2.5">
          <p class="text-sm font-medium text-gray-700 dark:text-gray-300">{{ group.title }}</p>
          <button
            type="button"
            class="text-sm text-gray-600 hover:text-gray-900 dark:text-gray-400 dark:hover:text-white"
            @click="checkGroup(group)"
          >
            Check all
          </button>
        </div>
        <div
          class="space-y-3 rounded-xl bg-white px-4 py-4 shadow-ui-md ring ring-gray-200 dark:bg-gray-850 dark:ring-gray-700/80"
        >
          <PermissionNode
            v-for="node in group.abilities"
            :key="node.value"
            :node="node"
            :checked="(value: string) => covered(group, value)"
            :locked="(value: string) => locked(group, value)"
            @toggle="(node, on) => toggle(group, node, on)"
          />
        </div>
      </div>
    </form>
  </div>
</template>
