<script setup lang="ts">
import { Link, router } from '@inertiajs/vue3'
import AdminIcon from '@/components/admin/icons/AdminIcon.vue'
import DataTablePanel from '@/components/admin/page/DataTablePanel.vue'
import PageHeader from '@/components/admin/page/PageHeader.vue'
import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import { useBreadcrumbs } from '@/lib/breadcrumbs'

type RoleRow = {
  id: number
  title: string
  handle: string
  superuser: boolean
  abilities: number
  users: number
  edit_url: string
}

defineProps<{ roles: RoleRow[] }>()

useBreadcrumbs([{ label: 'Roles' }])
</script>

<template>
  <div>
    <div v-if="!roles.length" class="mx-auto max-w-md py-14">
      <h1 class="mb-8 flex items-center justify-center gap-3 text-[25px] font-medium">
        <AdminIcon name="users" class="size-5 text-gray-500" />Roles
      </h1>
      <div class="rounded-2xl bg-gray-150 p-1.5 dark:bg-gray-950/35">
        <p class="px-4 pt-2 pb-3 text-sm">
          A role is a set of permissions you give to people. Everyone signing in holds one or more.
        </p>
        <Link
          href="/admin/roles/new"
          class="flex gap-4 rounded-xl bg-white p-5 shadow-ui-sm hover:bg-gray-50 dark:bg-gray-900 dark:hover:bg-gray-850"
        >
          <AdminIcon name="plus" class="mt-0.5 size-5 text-gray-500" />
          <div>
            <p class="font-medium">Create a role</p>
            <p class="mt-1 text-sm text-gray-600 dark:text-gray-400">Choose what the people holding it can do.</p>
          </div>
        </Link>
      </div>
    </div>

    <template v-else>
      <PageHeader title="Roles" icon="users">
        <template #actions>
          <Button as-child><Link href="/admin/roles/new">Create role</Link></Button>
        </template>
      </PageHeader>
      <DataTablePanel>
        <thead>
          <tr>
            <th>Title</th>
            <th>Handle</th>
            <th class="w-40">Permissions</th>
            <th class="w-24">Users</th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="role in roles" :key="role.id" class="cursor-pointer" @click="router.visit(role.edit_url)">
            <td>
              <Link :href="role.edit_url" class="font-medium hover:underline">{{ role.title }}</Link>
            </td>
            <td class="font-mono text-xs text-gray-500">{{ role.handle }}</td>
            <td class="text-sm">
              <Badge v-if="role.superuser" variant="secondary">Full access</Badge>
              <span v-else>{{ role.abilities }}</span>
            </td>
            <td class="text-sm">{{ role.users }}</td>
          </tr>
        </tbody>
      </DataTablePanel>
    </template>
  </div>
</template>
