<script setup lang="ts">
import { SliderRange, SliderRoot, SliderThumb, SliderTrack } from 'reka-ui'
import { computed, ref, watch } from 'vue'
import { toast } from 'vue-sonner'
import CpIcon from '@/components/cp/icons/CpIcon.vue'
import ListingFilters from '@/components/cp/listing/ListingFilters.vue'
import ListingPagination from '@/components/cp/listing/ListingPagination.vue'
import ListingSearch from '@/components/cp/listing/ListingSearch.vue'
import ListingTable from '@/components/cp/listing/ListingTable.vue'
import PageHeader from '@/components/cp/page/PageHeader.vue'
import { Button } from '@/components/ui/button'
import { DropdownMenu, DropdownMenuContent, DropdownMenuItem, DropdownMenuTrigger } from '@/components/ui/dropdown-menu'
import { ToggleGroup, ToggleGroupItem } from '@/components/ui/toggle-group'
import { useConfirm } from '@/lib/confirm'
import { usePreference } from '@/lib/preferences'
import AssetActionsMenu from './AssetActionsMenu.vue'
import AssetBulkBar, { type BulkAction } from './AssetBulkBar.vue'
import AssetContextMenu from './AssetContextMenu.vue'
import type { AssetMenuAction } from './assetMenu'
import AssetEditor from './AssetEditor.vue'
import AssetThumb from './AssetThumb.vue'
import { formatBytes, formatDuration, relativeTime, request, type AssetRow, type BrowseResponse } from './api'
import FolderIcon from './FolderIcon.vue'
import ReplacementPicker from './ReplacementPicker.vue'
import { useAssetActions } from './useAssetActions'
import { useUploads } from './useUploads'

export type BrowseParams = Record<string, string | number | null>

const props = withDefaults(
  defineProps<{
    data: BrowseResponse
    mode?: 'page' | 'select'
    selected?: number[]
    maxFiles?: number
    editingId?: number | null
  }>(),
  { mode: 'page', selected: () => [], maxFiles: 0, editingId: null },
)
const emit = defineEmits<{
  navigate: [params: BrowseParams]
  changed: []
  'update:selected': [ids: number[]]
  'update:editingId': [id: number | null]
  pick: [rows: AssetRow[]]
}>()

const listing = computed(() => props.data.listing)
const rows = computed(() => listing.value.rows)
const view = usePreference<'grid' | 'table'>('assets.view', 'grid')
const tileSize = usePreference<number>('assets.grid_size', 200)
const transparency = usePreference<boolean>('assets.transparency', false)
const q = ref(listing.value.search.value)
const selectedIds = ref<number[]>([...props.selected])
watch(
  () => props.selected,
  (ids) => (selectedIds.value = [...ids]),
)

const crumbs = computed(() => {
  const parts = props.data.folder ? props.data.folder.split('/') : []
  return parts.map((name, index) => ({ name, path: parts.slice(0, index + 1).join('/') }))
})

let searchTimer: ReturnType<typeof setTimeout> | undefined
watch(q, (value) => {
  clearTimeout(searchTimer)
  searchTimer = setTimeout(() => emit('navigate', { q: value, page: 1 }), 300)
})

function openFolder(path: string) {
  q.value = ''
  emit('navigate', { folder: path, q: '', page: 1 })
}

const transparentTypes = ['png', 'gif', 'webp', 'avif', 'svg']
function tileClasses(row: AssetRow) {
  if (!transparentTypes.includes(row.extension)) return ''
  return transparency.value ? 'bg-checkerboard' : 'bg-checkerboard before:opacity-0 hover:before:opacity-100'
}

function setSelection(ids: number[]) {
  selectedIds.value = ids
  emit('update:selected', ids)
}

function onTileClick(row: AssetRow) {
  if (props.mode === 'select' && props.maxFiles === 1) return emit('pick', [row])
  const ids = selectedIds.value
  if (ids.includes(row.id)) return setSelection(ids.filter((id) => id !== row.id))
  if (props.maxFiles && ids.length >= props.maxFiles) return toast.error(`You can pick up to ${props.maxFiles}`)
  setSelection([...ids, row.id])
}

function openEditor(id: number | null) {
  emit('update:editingId', id)
}

const replacementPicker = ref<InstanceType<typeof ReplacementPicker> | null>(null)
const actions = useAssetActions({
  folderOptions: () => props.data.folder_options,
  changed: () => emit('changed'),
  edit: (id) => openEditor(id),
  deleted: (id) => setSelection(selectedIds.value.filter((selected) => selected !== id)),
  pickReplacement: () => replacementPicker.value?.pick() ?? Promise.resolve(null),
})

const {
  rows: uploadRows,
  upload,
  dismiss,
} = useUploads(
  () => props.data.folder,
  () => emit('changed'),
)
const fileInput = ref<HTMLInputElement | null>(null)
function onFileInput(event: Event) {
  const input = event.target as HTMLInputElement
  if (input.files?.length) upload(input.files)
  input.value = ''
}

const dragDepth = ref(0)
const dragging = computed(() => dragDepth.value > 0)
function hasFiles(event: DragEvent) {
  return !!event.dataTransfer?.types.includes('Files')
}
function onDragEnter(event: DragEvent) {
  if (props.data.can.upload && hasFiles(event)) dragDepth.value += 1
}
function onDragLeave(event: DragEvent) {
  if (hasFiles(event)) dragDepth.value = Math.max(0, dragDepth.value - 1)
}
function onDrop(event: DragEvent) {
  if (!hasFiles(event)) return
  dragDepth.value = 0
  if (props.data.can.upload && event.dataTransfer?.files.length) upload(event.dataTransfer.files)
}

function onTileDragStart(row: AssetRow, event: DragEvent) {
  const ids = selectedIds.value.includes(row.id) ? selectedIds.value : [row.id]
  event.dataTransfer?.setData('application/x-nibble-assets', JSON.stringify(ids))
}
async function onFolderDrop(path: string, event: DragEvent) {
  const raw = event.dataTransfer?.getData('application/x-nibble-assets')
  if (!raw || !props.data.can.edit) return
  const ids = JSON.parse(raw) as number[]
  try {
    await Promise.all(ids.map((id) => request('PATCH', `/cp/media/${id}`, { asset: { folder: path } })))
    toast.success(`Moved ${ids.length} ${ids.length === 1 ? 'asset' : 'assets'}`)
    setSelection([])
    emit('changed')
  } catch (error) {
    toast.error((error as Error).message)
  }
}

const confirm = useConfirm()
async function createFolder() {
  const result = await confirm({
    title: 'Create Folder',
    confirmText: 'Create',
    fields: [{ handle: 'name', label: 'Name', options: [] }],
  })
  if (!result) return
  try {
    await request('POST', '/cp/media/folders', { parent: props.data.folder, name: result.name })
    emit('changed')
  } catch (error) {
    toast.error((error as Error).message)
  }
}
async function renameFolder(path: string) {
  const result = await confirm({
    title: 'Rename Folder',
    confirmText: 'Rename',
    fields: [{ handle: 'name', label: 'Name', options: [], value: path.split('/').pop() }],
  })
  if (!result) return
  try {
    await request('PATCH', '/cp/media/folders', { path, name: result.name })
    emit('changed')
  } catch (error) {
    toast.error((error as Error).message)
  }
}
async function deleteFolder(path: string) {
  const ok = await confirm({ title: `Delete ${path}?`, confirmText: 'Delete', dangerous: true })
  if (!ok) return
  try {
    await request('DELETE', `/cp/media/folders?path=${encodeURIComponent(path)}`)
    emit('changed')
  } catch (error) {
    toast.error((error as Error).message)
  }
}

const selectedRows = computed(() => rows.value.filter((row) => selectedIds.value.includes(row.id)))

async function bulk(handle: string, extra: Record<string, unknown> = {}) {
  try {
    const result = await request<{ updated: number }>('POST', '/cp/media/bulk', {
      handle,
      ids: selectedIds.value,
      ...extra,
    })
    toast.success(`${result.updated} ${result.updated === 1 ? 'asset' : 'assets'} updated`)
    setSelection([])
  } catch (error) {
    toast.error((error as Error).message)
  }
  emit('changed')
}

async function onBulk(action: BulkAction) {
  const count = selectedIds.value.length
  switch (action) {
    case 'copy':
    case 'rename':
    case 'replace':
    case 'reupload':
      return selectedRows.value[0] && actions.run(action, selectedRows.value[0])
    case 'download':
      return selectedRows.value.forEach((row) => actions.run('download', row))
    case 'duplicate':
      return bulk('duplicate')
    case 'move': {
      const result = await confirm({
        title: `Move ${count} ${count === 1 ? 'asset' : 'assets'}`,
        confirmText: 'Move',
        fields: [
          { handle: 'folder', label: 'Folder', options: props.data.folder_options, value: props.data.folder || 'root' },
        ],
      })
      if (result) return bulk('move', { folder: result.folder === 'root' ? '' : result.folder })
      return
    }
    case 'tag': {
      const result = await confirm({
        title: `Tag ${count} ${count === 1 ? 'asset' : 'assets'}`,
        confirmText: 'Add Tag',
        fields: [{ handle: 'tag', label: 'Tag', options: [] }],
      })
      if (result && result.tag) return bulk('tag', { tag: result.tag })
      return
    }
    case 'delete': {
      const used = selectedRows.value.filter((row) => row.usage_count > 0).length
      const ok = await confirm({
        title: `Delete ${count} ${count === 1 ? 'asset' : 'assets'}?`,
        description: used
          ? `${used} of them ${used === 1 ? 'is' : 'are'} used in content. They move to the trash.`
          : 'They move to the trash.',
        confirmText: 'Delete',
        dangerous: true,
      })
      if (ok) return bulk('trash')
    }
  }
}

const editingIndex = computed(() => rows.value.findIndex((row) => row.id === props.editingId))
function step(offset: number) {
  const row = rows.value[editingIndex.value + offset]
  if (row) openEditor(row.id)
}
</script>

<template>
  <div class="relative" @dragenter="onDragEnter" @dragleave="onDragLeave" @dragover.prevent @drop.prevent="onDrop">
    <div v-if="dragging" class="drag-notification">
      <CpIcon name="upload-cloud-large" class="size-8" />
      <span>Drop File to Upload</span>
    </div>
    <input ref="fileInput" class="hidden" type="file" multiple @change="onFileInput" />

    <PageHeader v-if="mode === 'page'" title="Assets" icon="assets">
      <template #actions>
        <Button v-if="data.can.upload" variant="outline" @click="fileInput?.click()"
          ><CpIcon name="upload" /> Upload</Button
        >
        <Button v-if="data.can.upload" variant="outline" @click="createFolder"
          ><CpIcon name="add-folder" /> Create Folder</Button
        >
        <ToggleGroup
          type="single"
          :model-value="view"
          variant="outline"
          @update:model-value="(value) => value && (view = value as 'grid' | 'table')"
        >
          <ToggleGroupItem value="grid" aria-label="Toggle grid"><CpIcon name="layout-grid" /></ToggleGroupItem>
          <ToggleGroupItem value="table" aria-label="Toggle table"><CpIcon name="layout-list" /></ToggleGroupItem>
        </ToggleGroup>
      </template>
    </PageHeader>

    <div class="flex items-center gap-2 py-3 sm:gap-3">
      <ListingSearch v-model="q" :placeholder="listing.search.placeholder" class="max-w-sm flex-1" />
      <div v-if="mode === 'page'" class="flex flex-1 items-center gap-2 py-3 sm:gap-3">
        <ListingFilters
          :filters="listing.filters"
          @change="
            (handle, value) => emit('navigate', { [handle]: Array.isArray(value) ? value.join(',') : value, page: 1 })
          "
        />
      </div>
      <template v-if="mode === 'select'">
        <div class="flex-1" />
        <Button v-if="data.can.upload" variant="outline" @click="fileInput?.click()"
          ><CpIcon name="upload" /> Upload</Button
        >
        <ToggleGroup
          type="single"
          :model-value="view"
          variant="outline"
          @update:model-value="(value) => value && (view = value as 'grid' | 'table')"
        >
          <ToggleGroupItem value="grid" aria-label="Toggle grid"><CpIcon name="layout-grid" /></ToggleGroupItem>
          <ToggleGroupItem value="table" aria-label="Toggle table"><CpIcon name="layout-list" /></ToggleGroupItem>
        </ToggleGroup>
      </template>
    </div>

    <div
      class="relative mb-8 w-full rounded-2xl bg-gray-150 p-1.75 pt-0 max-[600px]:p-1.25 dark:bg-gray-950/35 dark:inset-shadow-2xs dark:inset-shadow-black"
    >
      <header class="flex items-center justify-between gap-2 px-1 py-3">
        <nav class="flex flex-wrap items-center" aria-label="Folders">
          <Button variant="ghost" class="h-8! gap-2" @click="openFolder('')"><CpIcon name="home" /> All</Button>
          <template v-for="crumb in crumbs" :key="crumb.path">
            <span class="px-1 text-gray-400">/</span>
            <Button variant="ghost" class="h-8!" @click="openFolder(crumb.path)">{{ crumb.name }}</Button>
          </template>
        </nav>
        <div v-if="view === 'grid'" class="mr-2 flex items-center gap-2">
          <Button
            variant="ghost"
            size="icon-sm"
            aria-label="Transparency"
            :aria-pressed="transparency"
            @click="transparency = !transparency"
            ><CpIcon name="eye-slash" class="size-4"
          /></Button>
          <SliderRoot
            :model-value="[tileSize]"
            :min="60"
            :max="300"
            :step="10"
            aria-label="Tile size"
            class="relative flex h-2 w-24! touch-none items-center select-none"
            @update:model-value="(value) => value && (tileSize = value[0])"
          >
            <SliderTrack class="relative h-1 grow rounded-full bg-gray-300/80 dark:bg-gray-800"
              ><SliderRange class="absolute h-full rounded-full"
            /></SliderTrack>
            <SliderThumb
              class="block size-4 rounded-full bg-white shadow-ui-md focus:outline-hidden dark:bg-gray-400"
              aria-label="Tile size"
            />
          </SliderRoot>
        </div>
      </header>

      <div
        v-if="view === 'grid'"
        class="space-y-8 rounded-xl bg-white px-4 py-5 shadow-ui-md ring ring-gray-200 sm:px-4.5 dark:bg-gray-850 dark:ring-gray-700/80"
      >
        <ul v-if="uploadRows.length" class="space-y-2">
          <li v-for="row in uploadRows" :key="row.id" class="flex items-center gap-3 text-sm">
            <span class="w-48 truncate">{{ row.name }}</span>
            <span v-if="row.status === 'error'" class="flex-1 text-red-600">{{ row.error }}</span>
            <span v-else class="h-1.5 flex-1 overflow-hidden rounded-full bg-gray-200 dark:bg-gray-800"
              ><span class="block h-full bg-primary transition-[width]" :style="{ width: `${row.progress}%` }"
            /></span>
            <Button
              v-if="row.status === 'error'"
              variant="ghost"
              size="icon-xs"
              aria-label="Dismiss"
              @click="dismiss(row.id)"
              ><CpIcon name="x"
            /></Button>
          </li>
        </ul>

        <section v-if="data.folders.length" class="folder-grid-listing">
          <div
            v-for="folder in data.folders"
            :key="folder.path"
            class="group/folder relative p-1"
            @dragover.prevent
            @drop.prevent.stop="onFolderDrop(folder.path, $event)"
          >
            <button
              type="button"
              class="group h-[66px] w-[80px]"
              :aria-label="`Open ${folder.name}`"
              @click="openFolder(folder.path)"
            >
              <FolderIcon />
              <div
                class="mt-2 overflow-hidden text-center text-xs text-ellipsis whitespace-nowrap text-gray-500 dark:text-gray-300"
                :title="folder.name"
              >
                {{ folder.name }}
              </div>
            </button>
            <DropdownMenu v-if="mode === 'page' && (data.can.edit || data.can.delete)">
              <DropdownMenuTrigger as-child>
                <Button
                  variant="ghost"
                  size="icon-xs"
                  class="absolute end-0 top-0 bg-white opacity-0 group-hover/folder:opacity-100 focus:opacity-100 dark:bg-gray-900"
                  :aria-label="`Actions for ${folder.name}`"
                  ><CpIcon name="dots" class="size-3.5"
                /></Button>
              </DropdownMenuTrigger>
              <DropdownMenuContent align="start">
                <DropdownMenuItem v-if="data.can.edit" @click="renameFolder(folder.path)"
                  ><CpIcon name="rename" class="size-4" /> Rename</DropdownMenuItem
                >
                <DropdownMenuItem v-if="data.can.delete" variant="destructive" @click="deleteFolder(folder.path)"
                  ><CpIcon name="trash" class="size-4" /> Delete</DropdownMenuItem
                >
              </DropdownMenuContent>
            </DropdownMenu>
          </div>
        </section>

        <section
          v-if="rows.length"
          class="asset-grid-listing"
          :style="{ gridTemplateColumns: `repeat(auto-fill, minmax(${tileSize}px, 1fr))` }"
        >
          <div
            v-for="row in rows"
            :key="row.id"
            class="group relative"
            :class="{ selected: selectedIds.includes(row.id) }"
          >
            <AssetContextMenu :can="data.can" @run="(action) => actions.run(action, row)">
              <div class="asset-tile group relative bg-white dark:bg-gray-900" :class="tileClasses(row)">
                <button
                  type="button"
                  class="size-full"
                  :draggable="mode === 'page'"
                  :aria-label="row.filename"
                  :aria-pressed="selectedIds.includes(row.id)"
                  @click="onTileClick(row)"
                  @dblclick="openEditor(row.id)"
                  @dragstart="onTileDragStart(row, $event)"
                >
                  <div class="relative flex aspect-square size-full items-center justify-center">
                    <div class="asset-thumb"><AssetThumb :thumbnail="row.thumbnail" :extension="row.extension" /></div>
                  </div>
                </button>
                <div
                  class="absolute end-1 top-1 opacity-0 transition-opacity group-focus-within:opacity-100 group-hover:opacity-100 [&_button]:bg-white [&_button]:hover:bg-white dark:[&_button]:bg-gray-900"
                >
                  <AssetActionsMenu :can="data.can" :label="row.filename" @run="(action) => actions.run(action, row)" />
                </div>
              </div>
            </AssetContextMenu>
            <div class="asset-filename" :title="row.filename">{{ row.filename }}</div>
          </div>
        </section>

        <p v-if="!rows.length && !data.folders.length" class="py-8 text-center text-sm text-gray-500">
          {{ listing.search.value ? 'No assets match.' : 'There are no assets here yet.' }}
        </p>
      </div>

      <ListingTable
        v-else
        :columns="listing.columns.filter((column) => column.visible)"
        :rows="rows"
        :actions="listing.actions"
        :sort-column="listing.sort.column"
        :sort-direction="listing.sort.direction"
        :selected="new Set(selectedIds)"
        :row-menu="{
          component: AssetContextMenu,
          props: (row) => ({ can: data.can, onRun: (action: AssetMenuAction) => actions.run(action, row as AssetRow) }),
        }"
        @update:selected="(ids) => setSelection([...ids])"
        @sort="
          (handle) =>
            emit('navigate', {
              sort: handle,
              dir: listing.sort.column === handle && listing.sort.direction === 'asc' ? 'desc' : 'asc',
            })
        "
        @row-click="(row) => (mode === 'select' ? onTileClick(row as AssetRow) : openEditor(row.id))"
      >
        <template #prepend-rows>
          <tr
            v-for="folder in data.folders"
            :key="folder.path"
            class="cursor-pointer"
            @click="openFolder(folder.path)"
            @dragover.prevent
            @drop.prevent.stop="onFolderDrop(folder.path, $event)"
          >
            <td class="checkbox-column" />
            <td :colspan="listing.columns.filter((column) => column.visible).length">
              <span class="flex items-center gap-3"
                ><span class="w-8"><FolderIcon /></span>{{ folder.name }}</span
              >
            </td>
            <td class="actions-column" />
          </tr>
        </template>
        <template #cell-filename="{ row }">
          <span class="flex items-center gap-3">
            <span class="relative flex size-8 shrink-0 items-center justify-center overflow-hidden rounded-sm">
              <AssetThumb
                :thumbnail="(row as AssetRow).thumbnail"
                :extension="(row as AssetRow).extension"
                icon-class="size-6"
                class="size-full object-cover"
              />
            </span>
            {{ (row as AssetRow).filename }}
          </span>
        </template>
        <template #cell-size="{ value }">{{ formatBytes(value as number) }}</template>
        <template #cell-updated_at="{ value }">{{ relativeTime(value as string) }}</template>
        <template #cell-duration="{ value }">{{ formatDuration(value as number | null) }}</template>
        <template #row-actions="{ row }">
          <AssetActionsMenu
            :can="data.can"
            :label="(row as AssetRow).filename"
            @run="(action) => actions.run(action, row as AssetRow)"
          />
        </template>
      </ListingTable>

      <ListingPagination
        :page="listing.pagination.page"
        :per-page="listing.pagination.per_page"
        :total="listing.pagination.total"
        :pages="listing.pagination.pages"
        :per-page-options="listing.pagination.per_page_options"
        @page="(page) => emit('navigate', { page })"
        @per-page="(perPage) => emit('navigate', { per_page: perPage, page: 1 })"
      />
    </div>

    <AssetBulkBar
      v-if="mode === 'page'"
      :count="selectedIds.length"
      :can="data.can"
      @deselect="setSelection([])"
      @run="onBulk"
    />

    <ReplacementPicker v-if="mode === 'page'" ref="replacementPicker" />
    <AssetEditor
      :asset-id="editingId"
      :has-previous="editingIndex > 0"
      :has-next="editingIndex >= 0 && editingIndex < rows.length - 1"
      @close="openEditor(null)"
      @previous="step(-1)"
      @next="step(1)"
      @changed="emit('changed')"
    />
  </div>
</template>
