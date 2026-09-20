<script setup lang="ts">
import { Link, router } from '@inertiajs/vue3'
import { MoreHorizontal } from '@lucide/vue'
import AdminIcon from '@/components/admin/icons/AdminIcon.vue'
import AdminListing from '@/components/admin/listing/AdminListing.vue'
import AdminPanel from '@/components/admin/page/AdminPanel.vue'
import type { ListingProps, ListingRow } from '@/components/admin/listing/types'
import EntryCalendar, { type CalendarData } from '@/components/admin/listing/EntryCalendar.vue'
import EntryTree, { type TreeNode } from '@/components/admin/pages/EntryTree.vue'
import PageHeader from '@/components/admin/page/PageHeader.vue'
import { Button } from '@/components/ui/button'
import { DropdownMenu, DropdownMenuContent, DropdownMenuItem, DropdownMenuTrigger } from '@/components/ui/dropdown-menu'
import { ToggleGroup, ToggleGroupItem } from '@/components/ui/toggle-group'

defineProps<{
  collection: {
    handle: string
    title: string
    icon: string
    blueprints: { title: string; url: string }[]
    structured: boolean
    dated: boolean
    view: string
    views: string[]
  }
  create: { label: string; url: string } | null
  listing?: ListingProps
  tree?: TreeNode[]
  calendar?: CalendarData
}>()

const VIEW_ICONS: Record<string, string> = { list: 'layout-list', tree: 'navigation', calendar: 'calendar' }

const switchView = (view: string) => router.get(window.location.pathname, { view }, { preserveState: true })

function open(row: ListingRow) {
  if (row.edit_url) router.visit(row.edit_url)
}
</script>

<template>
  <div class="space-y-6">
    <PageHeader :title="collection.title" :icon="collection.icon" :breadcrumbs="[{ label: collection.title }]">
      <template #actions>
        <DropdownMenu v-if="collection.blueprints.length">
          <DropdownMenuTrigger as-child>
            <Button variant="ghost" size="icon-sm" aria-label="More actions"><MoreHorizontal /></Button>
          </DropdownMenuTrigger>
          <DropdownMenuContent align="end">
            <DropdownMenuItem v-for="blueprint in collection.blueprints" :key="blueprint.url" as-child>
              <Link :href="blueprint.url">View {{ blueprint.title }} blueprint</Link>
            </DropdownMenuItem>
          </DropdownMenuContent>
        </DropdownMenu>
        <ToggleGroup
          v-if="collection.views.length > 1"
          type="single"
          variant="outline"
          :model-value="collection.view"
          aria-label="View"
          @update:model-value="(view) => view && switchView(view as string)"
        >
          <ToggleGroupItem v-for="view in collection.views" :key="view" :value="view" :aria-label="`${view} view`">
            <AdminIcon :name="VIEW_ICONS[view]" />
          </ToggleGroupItem>
        </ToggleGroup>
        <Button v-if="create" as-child>
          <Link :href="create.url">{{ create.label }}</Link>
        </Button>
      </template>
    </PageHeader>

    <AdminListing v-if="listing" :listing="listing" @row-click="open" />
    <AdminPanel v-else-if="tree" title="Tree Structure" bare>
      <EntryTree :nodes="tree" :collection="collection.handle" />
    </AdminPanel>

    <EntryCalendar v-else-if="calendar" :calendar="calendar" :create-url="create?.url ?? null" />
  </div>
</template>
