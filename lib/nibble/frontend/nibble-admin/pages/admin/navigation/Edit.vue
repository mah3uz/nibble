<script setup lang="ts">
import { Link, router, usePage } from '@inertiajs/vue3'
import { computed, ref } from 'vue'
import AdminIcon from '@/components/admin/icons/AdminIcon.vue'
import NavTree from '@/components/admin/navigation/NavTree.vue'
import type { NavEntry, NavTreeItem } from '@/components/admin/navigation/types'
import PageHeader from '@/components/admin/page/PageHeader.vue'
import { Button } from '@/components/ui/button'
import { skipNextGuard, useDirtyGuard } from '@/lib/dirty-guard'

const props = defineProps<{
  menu: { handle: string; title: string; max_depth: number; locale: string }
  tree: NavTreeItem[]
  records: NavEntry[]
}>()

const page = usePage<{ errors: Record<string, string> }>()
const items = ref<NavTreeItem[]>(props.tree)
const processing = ref(false)
const baseline = ref(JSON.stringify(props.tree))

const dirty = computed(() => JSON.stringify(items.value) !== baseline.value)
const error = computed(() => page.props.errors?.tree)
useDirtyGuard(() => dirty.value)

function save() {
  processing.value = true
  skipNextGuard()
  router.patch(
    `/admin/navigation/${props.menu.handle}`,
    { tree: items.value },
    {
      preserveScroll: true,
      onSuccess: () => (baseline.value = JSON.stringify(items.value)),
      onFinish: () => (processing.value = false),
    },
  )
}
</script>

<template>
  <div class="mx-auto max-w-5xl">
    <Link
      href="/admin/navigation"
      class="relative z-10 -mb-6 flex w-fit items-center gap-1 pt-6 text-sm text-gray-600 hover:text-gray-900 dark:text-gray-400 dark:hover:text-white"
    >
      <AdminIcon name="chevron-left" class="size-4" />Navigation
    </Link>
    <PageHeader
      :title="menu.title"
      icon="navigation"
      :breadcrumbs="[{ label: 'Navigation', url: '/admin/navigation' }, { label: menu.title }]"
    >
      <template #actions><Button :disabled="processing" @click="save">Save</Button></template>
    </PageHeader>
    <p v-if="error" class="mb-4 text-sm text-destructive">{{ error }}</p>
    <NavTree v-model="items" :depth="0" :max-depth="menu.max_depth" :entries="records" />
  </div>
</template>
