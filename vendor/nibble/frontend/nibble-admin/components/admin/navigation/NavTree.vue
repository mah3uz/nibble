<script setup lang="ts">
import { useSortable } from '@vueuse/integrations/useSortable'
import { AlertTriangle, GripVertical, Pencil, Plus, Trash2 } from '@lucide/vue'
import { computed, ref, useTemplateRef } from 'vue'
import { Button } from '@/components/ui/button'
import NavItemEditor from './NavItemEditor.vue'
import type { NavEntry, NavTreeItem } from './types'

const props = defineProps<{ depth: number; maxDepth: number; entries: NavEntry[] }>()
const items = defineModel<NavTreeItem[]>({ default: () => [] })

const addLabel = computed(() => (props.depth === 0 ? 'Add link' : 'Add sub-link'))

function entryFor(item: NavTreeItem): NavEntry | undefined {
  return item.link.type === 'url'
    ? undefined
    : props.entries.find((e) => e.type === item.link.type && e.id === item.link.id)
}
function linkSummary(item: NavTreeItem): string {
  if (item.link.type === 'url') return item.link.url
  return entryFor(item)?.path ?? 'Missing (deleted)'
}
function notLive(item: NavTreeItem): boolean {
  if (item.link.type === 'url') return false
  const entry = entryFor(item)
  return !entry || !entry.live
}

const editorOpen = ref(false)
const editingIndex = ref<number | null>(null)
function openNew() {
  editingIndex.value = null
  editorOpen.value = true
}
function openEdit(index: number) {
  editingIndex.value = index
  editorOpen.value = true
}
function onSave(item: NavTreeItem) {
  items.value =
    editingIndex.value === null
      ? [...items.value, item]
      : items.value.map((existing, i) => (i === editingIndex.value ? item : existing))
  editorOpen.value = false
}
function remove(index: number) {
  items.value = items.value.filter((_, i) => i !== index)
}

const listRef = useTemplateRef<HTMLElement>('list')
useSortable(listRef, items, {
  handle: '.drag-handle',
  forceFallback: true,
  dragClass: 'sortable-drag-clone',
  ghostClass: 'sortable-ghost-placeholder',
})
</script>

<template>
  <div class="space-y-2">
    <div ref="list" class="space-y-2">
      <div v-for="(item, index) in items" :key="item.id" class="rounded-md border">
        <div class="flex items-center gap-2 p-2">
          <GripVertical class="drag-handle size-4 shrink-0 cursor-grab text-muted-foreground" />
          <div class="min-w-0 flex-1">
            <div class="flex flex-wrap items-center gap-2">
              <span class="truncate text-sm font-medium">{{ item.title }}</span>
              <span v-if="notLive(item)" class="inline-flex items-center gap-1 text-xs text-amber-600">
                <AlertTriangle class="size-3" /> not live
              </span>
            </div>
            <p class="truncate text-xs text-muted-foreground">{{ linkSummary(item) }}</p>
          </div>
          <Button type="button" size="icon-sm" variant="ghost" aria-label="Edit" @click="openEdit(index)"
            ><Pencil
          /></Button>
          <Button type="button" size="icon-sm" variant="ghost" aria-label="Remove" @click="remove(index)"
            ><Trash2
          /></Button>
        </div>
        <div v-if="depth < maxDepth" class="border-t p-2 pl-8">
          <NavTree v-model="item.children" :depth="depth + 1" :max-depth="maxDepth" :entries="entries" />
        </div>
      </div>
    </div>
    <Button type="button" variant="outline" size="sm" @click="openNew"><Plus /> {{ addLabel }}</Button>
    <NavItemEditor
      v-model:open="editorOpen"
      :item="editingIndex === null ? null : (items[editingIndex] ?? null)"
      :entries="entries"
      @save="onSave"
    />
  </div>
</template>
