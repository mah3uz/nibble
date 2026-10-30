<script setup lang="ts">
import { useSortable } from '@vueuse/integrations/useSortable'
import {
  AlertCircle,
  AlertTriangle,
  ArrowDown,
  ArrowLeft,
  ArrowRight,
  ArrowUp,
  CalendarClock,
  ChevronRight,
  Copy,
  ExternalLink,
  EyeOff,
  GripVertical,
  MoreHorizontal,
  Pencil,
  Trash2,
} from '@lucide/vue'
import type { SortableEvent } from 'sortablejs'
import { computed, ref, useTemplateRef } from 'vue'
import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from '@/components/ui/dropdown-menu'
import { formatDateTime } from '@nibble-cp/lib/format'
import { useNavEditor } from './context'
import NavAddButton from './NavAddButton.vue'
import NavItemEditor from './NavItemEditor.vue'
import {
  QUERY_SORTS,
  canNest,
  duplicate,
  fits,
  holdsChildren,
  itemAt,
  nest,
  pathOf,
  shift,
  unnest,
  type Path,
} from './tree'
import type { NavKind, NavTreeItem } from './types'

const props = defineProps<{ path: Path; inHidden?: boolean }>()
const editor = useNavEditor()
const { menu, entries, queryRecords, assets, errors, collapsed } = editor

const depth = computed(() => props.path.length)
const items = computed(() =>
  depth.value ? (itemAt(editor.tree.value, props.path)?.children ?? []) : editor.tree.value,
)
const nests = computed(() => canNest(depth.value, menu.max_depth))
const owner = computed(() => (depth.value ? itemAt(editor.tree.value, props.path) : undefined))
const addable = computed(() => !owner.value || holdsChildren(owner.value, menu.kinds))
const addLabel = computed(() => (depth.value === 0 ? 'Add link' : 'Add sub-link'))
const helpId = `nav-${menu.handle}-move-help`

const quoted = (item: NavTreeItem) => `“${item.title}”`
// Children a kind no longer allows stay on screen, so they can be moved out.
const holds = (item: NavTreeItem) => nests.value && (holdsChildren(item, menu.kinds) || item.children.length > 0)
const kindLabel = (item: NavTreeItem) =>
  item.kind === 'query' ? 'List of pages' : menu.kinds?.find((kind) => kind.handle === item.kind)?.display
const here = (index: number): Path => [...props.path, index]

function entryFor(item: NavTreeItem) {
  const link = item.link
  return link && (link.type === 'entry' || link.type === 'term')
    ? entries.find((e) => e.type === link.type && e.id === link.id)
    : undefined
}
function globalFor(ref: string) {
  for (const global of menu.globals ?? [])
    for (const field of global.fields) if (ref === `global:${global.handle}.${field.handle}`) return { global, field }
  return undefined
}
function summary(item: NavTreeItem): string {
  const link = item.link
  if (item.kind === 'query') return querySummary(item)
  if (!link) return item.kind === 'heading' ? 'Heading' : 'No link'
  if (link.type === 'url') return link.url
  if (link.type === 'global') {
    const found = globalFor(link.ref)
    return found ? `${found.global.title} › ${found.field.display}` : `${link.ref} (missing)`
  }
  if (link.type === 'asset') return assets.value[String(link.id)]?.filename ?? 'Missing (deleted)'
  return entryFor(item)?.path ?? 'Missing (deleted)'
}
function querySummary(item: NavTreeItem): string {
  const query = item.query
  if (!query?.collection) return 'No collection chosen'
  const named = (type: string, id?: number) =>
    id === undefined ? undefined : (queryRecords.find((r) => r.type === type && r.id === id)?.title ?? 'a deleted one')
  const parent = named('entry', query.parent)
  const term = named('term', query.term?.id)
  const sort = query.sort && (QUERY_SORTS.find((one) => one.value === query.sort)?.label ?? `Sorted by ${query.sort}`)
  return [
    `${menu.queries?.find((q) => q.handle === query.collection)?.title ?? query.collection}${parent ? ` under “${parent}”` : ''}${term ? ` in “${term}”` : ''}`,
    sort && sort.toLowerCase(),
    `up to ${query.limit ?? 50}`,
  ]
    .filter(Boolean)
    .join(', ')
}
function schedule(item: NavTreeItem): string | null {
  const from = item.show_from && formatDateTime(item.show_from)
  const until = item.show_until && formatDateTime(item.show_until)
  if (from && until) return `${from} – ${until}`
  return from ? `From ${from}` : until ? `Until ${until}` : null
}
function warning(item: NavTreeItem): string | null {
  const link = item.link
  if (link?.type === 'entry' || link?.type === 'term') return entryFor(item)?.live ? null : 'Not live yet'
  if (link?.type === 'global') return globalFor(link.ref)?.field.address ? null : 'No address yet'
  return null
}

const editorOpen = ref(false)
const editingIndex = ref<number | null>(null)
const addingKind = ref<NavKind>('link')
function openNew(kind: NavKind) {
  editingIndex.value = null
  addingKind.value = kind
  editorOpen.value = true
}
function openEdit(index: number) {
  editingIndex.value = index
  editorOpen.value = true
}
function onSave(item: NavTreeItem) {
  if (editingIndex.value === null) items.value.push(item)
  else items.value.splice(editingIndex.value, 1, item)
  const rest = { ...errors.value }
  delete rest[item.id]
  errors.value = rest
  editorOpen.value = false
}
function remove(index: number) {
  items.value.splice(index, 1)
}

function toggle(item: NavTreeItem) {
  const next = new Set(collapsed.value)
  if (!next.delete(item.id)) next.add(item.id)
  collapsed.value = next
}

const moves = {
  up: (index: number) => shift(editor.tree.value, here(index), -1),
  down: (index: number) => shift(editor.tree.value, here(index), 1),
  in: (index: number) => nest(editor.tree.value, here(index), menu.max_depth, menu.kinds),
  out: (index: number) => unnest(editor.tree.value, here(index)),
}
const verbs = { up: 'Moved up', down: 'Moved down', in: 'Moved down a level', out: 'Moved up a level' }
const KEYS: Record<string, keyof typeof moves> = {
  ArrowUp: 'up',
  ArrowDown: 'down',
  ArrowRight: 'in',
  ArrowLeft: 'out',
}

function run(move: keyof typeof moves, index: number) {
  const item = items.value[index]!
  editor.change(moves[move](index), item.id, `${verbs[move]}: ${quoted(item)}.`)
}
function onHandleKey(event: KeyboardEvent, index: number) {
  const move = KEYS[event.key]
  if (!move) return
  event.preventDefault()
  run(move, index)
}
function copyItem(index: number) {
  const item = items.value[index]!
  editor.change(duplicate(editor.tree.value, here(index)), item.id, `Duplicated ${quoted(item)}.`)
}

const parentPath = (list: HTMLElement): Path => JSON.parse(list.dataset.path ?? '[]')
function canDrop(list: HTMLElement, dragged: HTMLElement): boolean {
  if (dragged.contains(list)) return false
  const from = pathOf(editor.tree.value, dragged.dataset.id ?? '')
  const item = from && itemAt(editor.tree.value, from)
  const parent = parentPath(list)
  const holder = parent.length ? itemAt(editor.tree.value, parent) : undefined
  return !!item && fits(item, parent.length, menu.max_depth) && (!holder || holdsChildren(holder, menu.kinds))
}

const listRef = useTemplateRef<HTMLElement>('list')
useSortable(listRef, items, {
  handle: '.drag-handle',
  forceFallback: true,
  dragClass: 'sortable-drag-clone',
  ghostClass: 'sortable-ghost-placeholder',
  group: { name: `nav-${menu.handle}`, put: (to, _from, dragged) => canDrop(to.el, dragged) },
  onUpdate: () => {},
  onEnd: (event: SortableEvent) => {
    const { from, to, item, oldIndex, newIndex } = event
    if (oldIndex === undefined || newIndex === undefined || (from === to && oldIndex === newIndex)) return
    // Vue owns these nodes, so Sortable's move is undone and the tree re-renders from the data.
    item.remove()
    from.insertBefore(item, from.children[oldIndex] ?? null)
    editor.moveTo([...parentPath(from), oldIndex], parentPath(to), newIndex)
  },
})
</script>

<template>
  <div class="space-y-2">
    <div ref="list" class="space-y-2" :data-path="JSON.stringify(path)">
      <div
        v-for="(item, index) in items"
        :key="item.id"
        :data-id="item.id"
        class="rounded-md border"
        :class="[item.hidden && !inHidden && 'opacity-60', errors[item.id] && 'border-destructive']"
      >
        <div class="flex items-center gap-2 p-2">
          <button
            type="button"
            class="drag-handle -m-1 shrink-0 cursor-grab rounded-sm p-1 text-muted-foreground outline-none focus-visible:focus-outline"
            :data-move="item.id"
            :aria-label="`Move ${quoted(item)}`"
            :aria-describedby="helpId"
            @keydown="onHandleKey($event, index)"
          >
            <GripVertical class="size-4" />
          </button>
          <button
            v-if="holds(item) && item.children.length"
            type="button"
            class="-m-1 shrink-0 rounded-sm p-1 text-muted-foreground outline-none hover:text-foreground focus-visible:focus-outline"
            :aria-expanded="!collapsed.has(item.id)"
            :aria-label="`${quoted(item)}: ${item.children.length} ${item.children.length === 1 ? 'item' : 'items'} inside`"
            @click="toggle(item)"
          >
            <ChevronRight class="size-4 transition-transform" :class="!collapsed.has(item.id) && 'rotate-90'" />
          </button>
          <span v-else-if="nests" class="w-4 shrink-0" />
          <div class="min-w-0 flex-1">
            <div class="flex flex-wrap items-center gap-x-2 gap-y-1">
              <span class="truncate text-sm font-medium">{{ item.title }}</span>
              <Badge v-if="kindLabel(item)" variant="outline">{{ kindLabel(item) }}</Badge>
              <Badge v-if="item.hidden"><EyeOff /> Hidden</Badge>
              <Badge v-if="schedule(item)" variant="outline"><CalendarClock /> {{ schedule(item) }}</Badge>
              <span v-if="warning(item)" class="inline-flex items-center gap-1 text-xs text-amber-600">
                <AlertTriangle class="size-3" /> {{ warning(item) }}
              </span>
              <span v-if="collapsed.has(item.id) && item.children.length" class="text-xs text-muted-foreground"
                >{{ item.children.length }} inside</span
              >
            </div>
            <p class="flex min-w-0 items-center gap-1 text-xs text-muted-foreground">
              <span class="truncate" :class="!item.link && item.kind !== 'query' && 'italic'">{{ summary(item) }}</span>
              <template v-if="item.link && item.new_tab"
                ><ExternalLink class="size-3 shrink-0" aria-hidden="true" /><span class="sr-only"
                  >, opens in a new tab</span
                ></template
              >
            </p>
          </div>
          <Button
            type="button"
            size="icon-sm"
            variant="ghost"
            :aria-label="`Edit ${quoted(item)}`"
            @click="openEdit(index)"
            ><Pencil
          /></Button>
          <Button
            type="button"
            size="icon-sm"
            variant="ghost"
            :aria-label="`Remove ${quoted(item)}`"
            @click="remove(index)"
            ><Trash2
          /></Button>
          <DropdownMenu>
            <DropdownMenuTrigger as-child>
              <Button type="button" size="icon-sm" variant="ghost" :aria-label="`More for ${quoted(item)}`"
                ><MoreHorizontal
              /></Button>
            </DropdownMenuTrigger>
            <DropdownMenuContent align="end" class="min-w-48">
              <DropdownMenuItem @select="copyItem(index)"><Copy />Duplicate</DropdownMenuItem>
              <DropdownMenuSeparator />
              <DropdownMenuItem :disabled="!moves.up(index)" @select="run('up', index)"
                ><ArrowUp />Move up</DropdownMenuItem
              >
              <DropdownMenuItem :disabled="!moves.down(index)" @select="run('down', index)"
                ><ArrowDown />Move down</DropdownMenuItem
              >
              <DropdownMenuItem :disabled="!moves.in(index)" @select="run('in', index)"
                ><ArrowRight />Move under the item above</DropdownMenuItem
              >
              <DropdownMenuItem :disabled="!moves.out(index)" @select="run('out', index)"
                ><ArrowLeft />Move out a level</DropdownMenuItem
              >
            </DropdownMenuContent>
          </DropdownMenu>
        </div>
        <ul v-if="errors[item.id]" class="space-y-1 px-2 pb-2 text-xs text-destructive" role="list">
          <li v-for="message in errors[item.id]!.messages" :key="message" class="flex gap-1.5">
            <AlertCircle class="mt-px size-3.5 shrink-0" />{{ message }}
          </li>
        </ul>
        <p v-if="item.kind === 'query'" class="border-t px-2 py-1.5 pl-8 text-xs text-muted-foreground">
          The site fills this list with the matching pages.
        </p>
        <div v-else-if="holds(item) && !collapsed.has(item.id)" class="border-t p-2 pl-8">
          <NavTree :path="here(index)" :in-hidden="inHidden || item.hidden" />
        </div>
      </div>
    </div>
    <NavAddButton v-if="addable" :label="addLabel" @add="openNew" />
    <p v-if="depth === 0" :id="helpId" class="sr-only">
      Use the arrow keys to move it: up and down to reorder, right to put it under the item above, left to move it out a
      level.
    </p>
    <NavItemEditor
      v-model:open="editorOpen"
      :item="editingIndex === null ? null : (items[editingIndex] ?? null)"
      :kind="addingKind"
      @save="onSave"
    />
  </div>
</template>
