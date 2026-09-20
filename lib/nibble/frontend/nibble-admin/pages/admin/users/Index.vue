<script setup lang="ts">
import { Link, useForm } from '@inertiajs/vue3'
import { ref } from 'vue'
import AdminListing from '@/components/admin/listing/AdminListing.vue'
import type { ListingProps } from '@/components/admin/listing/types'
import PageHeader from '@/components/admin/page/PageHeader.vue'
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
import { useBreadcrumbs } from '@/lib/breadcrumbs'

type RoleOption = { id: number; title: string; superuser: boolean }

defineProps<{ listing: ListingProps; roles: RoleOption[] }>()

const inviting = ref(false)
const form = useForm({ name: '', email_address: '', role_ids: [] as number[] })

function toggleRole(id: number, on: boolean) {
  form.role_ids = on ? [...form.role_ids, id] : form.role_ids.filter((value) => value !== id)
}

async function invite() {
  form
    .transform((data) => ({ user: data }))
    .post('/admin/users', {
      onSuccess: () => {
        inviting.value = false
        form.reset()
      },
    })
}

useBreadcrumbs([{ label: 'Users' }])
</script>

<template>
  <div>
    <PageHeader title="Users" icon="users">
      <template #actions>
        <Button @click="inviting = true">Invite user</Button>
      </template>
    </PageHeader>

    <AdminListing :listing="listing" :exportable="false">
      <template #cell-email_address="{ row }">
        <Link v-if="row.editable" :href="row.edit_url as string" class="font-medium hover:underline">
          {{ row.email_address }}
        </Link>
        <span v-else class="font-medium">{{ row.email_address }}</span>
        <span v-if="row.you" class="ms-1 text-gray-500">(you)</span>
        <span v-else-if="!row.editable" class="ms-1 text-gray-500">(administrator)</span>
      </template>
      <template #cell-roles="{ row }">
        <span class="flex flex-wrap gap-1">
          <Badge v-for="title in (row.roles as string[]) || []" :key="title" variant="secondary">{{ title }}</Badge>
          <span v-if="!(row.roles as string[])?.length" class="text-gray-500">No role</span>
        </span>
      </template>
      <template #cell-last_login_at="{ value }">
        <span v-if="value">{{ new Date(value as string).toLocaleDateString(undefined, { dateStyle: 'medium' }) }}</span>
        <span v-else class="text-gray-500">Never</span>
      </template>
    </AdminListing>

    <Dialog v-model:open="inviting">
      <DialogContent>
        <DialogHeader>
          <DialogTitle>Invite user</DialogTitle>
          <DialogDescription>
            They get an email with a link to choose a password. It lasts seven days.
          </DialogDescription>
        </DialogHeader>
        <form id="invite-form" class="space-y-4" @submit.prevent="invite">
          <div class="space-y-1.5">
            <Label for="invite-name">Name</Label>
            <Input id="invite-name" v-model="form.name" required :aria-invalid="!!form.errors.name" />
            <p v-if="form.errors.name" class="text-sm text-red-600">{{ form.errors.name }}</p>
          </div>
          <div class="space-y-1.5">
            <Label for="invite-email">Email</Label>
            <Input
              id="invite-email"
              v-model="form.email_address"
              type="email"
              required
              :aria-invalid="!!form.errors.email_address"
            />
            <p v-if="form.errors.email_address" class="text-sm text-red-600">{{ form.errors.email_address }}</p>
          </div>
          <fieldset class="space-y-2">
            <legend class="text-sm font-medium">Roles</legend>
            <label v-for="role in roles" :key="role.id" class="flex items-center gap-2.5 text-sm">
              <Checkbox
                :model-value="form.role_ids.includes(role.id)"
                @update:model-value="(on) => toggleRole(role.id, !!on)"
              />
              {{ role.title }}
            </label>
          </fieldset>
        </form>
        <DialogFooter show-close-button>
          <Button type="submit" form="invite-form" :disabled="form.processing">Send invitation</Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  </div>
</template>
