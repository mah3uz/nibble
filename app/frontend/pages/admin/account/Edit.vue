<script setup lang="ts">
import { useForm, usePage } from '@inertiajs/vue3'
import { computed, ref } from 'vue'
import PasskeysPanel from '@/components/admin/account/PasskeysPanel.vue'
import TwoFactorPanel from '@/components/admin/account/TwoFactorPanel.vue'
import AdminPanel from '@/components/admin/page/AdminPanel.vue'
import PageHeader from '@/components/admin/page/PageHeader.vue'
import { Button } from '@/components/ui/button'
import { Dialog, DialogContent, DialogFooter, DialogHeader, DialogTitle } from '@/components/ui/dialog'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select'
import { useAdmin, type AdminPreferences } from '@/lib/admin'
import { usePreference } from '@/lib/preferences'

const props = defineProps<{
  two_factor: {
    enabled: boolean
    required: boolean
    pending: { secret: string; uri: string; qr: string } | null
    recovery_codes_left: number
    recovery_codes: string[] | null
  }
  passkeys: { id: number; name: string; created_at: string; last_used_at: string | null }[]
}>()

const admin = useAdmin()
const errors = computed(() => usePage().props.errors as unknown as Record<string, string>)

const nameForm = useForm<{ name: string }>({ name: admin.value.user?.name ?? '' })
function saveName() {
  nameForm.transform((data) => ({ user: data })).patch('/admin/account', { onSuccess: () => nameForm.defaults() })
}

const passwordForm = useForm<{ current_password: string; password: string; password_confirmation: string }>({
  current_password: '',
  password: '',
  password_confirmation: '',
})
const changingPassword = ref(false)
const passkeysOpen = ref(false)
function changePassword() {
  passwordForm
    .transform((data) => ({ user: data }))
    .patch('/admin/account', {
      preserveScroll: true,
      onSuccess: () => {
        passwordForm.reset()
        changingPassword.value = false
      },
    })
}

const theme = usePreference<AdminPreferences['theme']>('theme', 'system')
const startPage = usePreference<AdminPreferences['start_page']>('start_page', 'dashboard')
const afterSave = usePreference<AdminPreferences['after_save']>('after_save', 'continue')
</script>

<template>
  <div class="mx-auto max-w-5xl">
    <PageHeader :title="admin.user?.email_address ?? 'Account'" icon="users">
      <template #actions>
        <Button type="button" variant="outline" @click="passkeysOpen = true">Passkeys</Button>
        <TwoFactorPanel :two-factor="props.two_factor" :has-passkeys="props.passkeys.length > 0" />
        <Button type="button" variant="outline" @click="changingPassword = true">Change Password</Button>
        <Button type="submit" form="profile-form" :disabled="nameForm.processing">Save</Button>
      </template>
    </PageHeader>

    <AdminPanel>
      <form id="profile-form" class="space-y-6" @submit.prevent="saveName">
        <div class="space-y-2">
          <Label for="name">Name</Label>
          <Input id="name" v-model="nameForm.name" required />
          <p v-if="errors.name" class="text-sm text-destructive">{{ errors.name }}</p>
        </div>
        <div class="space-y-2">
          <Label for="email">Email Address</Label>
          <Input id="email" :model-value="admin.user?.email_address" readonly />
        </div>
      </form>
    </AdminPanel>

    <AdminPanel title="Preferences">
      <div class="space-y-4">
        <div class="flex items-center justify-between gap-4">
          <Label for="theme">Theme</Label>
          <Select v-model="theme">
            <SelectTrigger id="theme" class="w-48"><SelectValue /></SelectTrigger>
            <SelectContent>
              <SelectItem value="system">System</SelectItem>
              <SelectItem value="light">Light</SelectItem>
              <SelectItem value="dark">Dark</SelectItem>
            </SelectContent>
          </Select>
        </div>
        <div class="flex items-center justify-between gap-4">
          <Label for="start_page">Start page</Label>
          <Select v-model="startPage">
            <SelectTrigger id="start_page" class="w-48"><SelectValue /></SelectTrigger>
            <SelectContent>
              <SelectItem value="dashboard">Dashboard</SelectItem>
              <SelectItem v-for="collection in admin.collections" :key="collection.handle" :value="collection.handle">{{
                collection.title
              }}</SelectItem>
            </SelectContent>
          </Select>
        </div>
        <div class="flex items-center justify-between gap-4">
          <Label for="after_save">After saving</Label>
          <Select v-model="afterSave">
            <SelectTrigger id="after_save" class="w-48"><SelectValue /></SelectTrigger>
            <SelectContent>
              <SelectItem value="continue">Keep editing</SelectItem>
              <SelectItem value="listing">Go to the list</SelectItem>
              <SelectItem value="create_another">Create another</SelectItem>
            </SelectContent>
          </Select>
        </div>
      </div>
    </AdminPanel>

    <PasskeysPanel v-model:open="passkeysOpen" :passkeys="props.passkeys" />

    <Dialog v-model:open="changingPassword">
      <DialogContent class="sm:max-w-2xl">
        <DialogHeader>
          <DialogTitle>Change Password</DialogTitle>
        </DialogHeader>
        <form id="password-change-form" class="space-y-5" @submit.prevent="changePassword">
          <div class="space-y-2">
            <Label for="current_password">Current Password</Label>
            <Input
              id="current_password"
              v-model="passwordForm.current_password"
              type="password"
              autocomplete="current-password"
              required
            />
            <p v-if="errors.current_password" class="text-sm text-destructive">{{ errors.current_password }}</p>
          </div>
          <div class="space-y-2">
            <Label for="password">Password</Label>
            <Input id="password" v-model="passwordForm.password" type="password" autocomplete="new-password" required />
            <p v-if="errors.password" class="text-sm text-destructive">{{ errors.password }}</p>
          </div>
          <div class="space-y-2">
            <Label for="password_confirmation">Password Confirmation</Label>
            <Input
              id="password_confirmation"
              v-model="passwordForm.password_confirmation"
              type="password"
              autocomplete="new-password"
              required
            />
            <p v-if="errors.password_confirmation" class="text-sm text-destructive">
              {{ errors.password_confirmation }}
            </p>
          </div>
          <p class="text-sm text-gray-600 dark:text-gray-400">Changing your password signs out every other session.</p>
        </form>
        <DialogFooter>
          <Button type="button" variant="ghost" @click="changingPassword = false">Cancel</Button>
          <Button type="submit" form="password-change-form" :disabled="passwordForm.processing">Change Password</Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  </div>
</template>
