<script setup lang="ts">
import { useSortable } from '@vueuse/integrations/useSortable'
import { computed, ref, useTemplateRef, watch } from 'vue'
import { toast } from 'vue-sonner'
import type { AssetRow } from '@/components/admin/assets/api'
import AssetEditor from '@/components/admin/assets/AssetEditor.vue'
import AssetSelector from '@/components/admin/assets/AssetSelector.vue'
import FileIcon from '@/components/admin/assets/FileIcon.vue'
import { useUploads } from '@/components/admin/assets/useUploads'
import AdminIcon from '@/components/admin/icons/AdminIcon.vue'
import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import { useConfirm } from '@/lib/confirm'
import type { ItemSummary } from '../../lib/relationships'
import { fieldtypeEmits, fieldtypeProps, useFieldtype } from '../useFieldtype'

type Item = { asset: string; alt: string | null }

const props = defineProps(fieldtypeProps)
const emit = defineEmits(fieldtypeEmits)
const { update, updateMeta, isReadOnly, expose } = useFieldtype(emit, props)
defineExpose(expose)

const items = ref<Item[]>([])
watch(
  () => props.value,
  (value) => (items.value = (Array.isArray(value) ? value : value ? [value] : []) as Item[]),
  { immediate: true },
)
const known = computed(
  () => new Map(((props.meta.data as ItemSummary[]) ?? []).map((asset) => [String(asset.id), asset])),
)
const max = computed(() => Number(props.config.max_files) || 0)
const altMode = computed(() => (props.config.alt as string) || 'optional')
const folder = computed(() => (props.config.folder as string) || '')
const allowedTypes = computed(() => (props.config.allowed_types as string[]) ?? [])
const canAdd = computed(() => !isReadOnly.value && (!max.value || max.value === 1 || items.value.length < max.value))
const room = computed(() => (max.value === 1 ? 1 : max.value ? max.value - items.value.length : 0))
const canUpload = computed(() => canAdd.value && props.config.allow_uploads !== false)
const listMode = computed(() => props.config.mode === 'list')

function extension(summary: ItemSummary | undefined) {
  return (
    String(summary?.filename ?? summary?.title ?? '')
      .split('.')
      .pop() ?? ''
  )
}

function emitItems(next: Item[]) {
  update(max.value === 1 ? (next[0] ?? null) : next)
}

function add(rows: AssetRow[]) {
  const fresh = rows.filter((row) => !items.value.some((item) => item.asset === String(row.id)))
  if (!fresh.length) return
  const summaries = fresh.map((row) => ({
    id: String(row.id),
    title: row.title,
    filename: row.filename,
    url: row.url,
    thumbnail: row.thumbnail,
    alt: row.alt,
    kind: row.kind,
  }))
  updateMeta({ ...props.meta, data: [...((props.meta.data as ItemSummary[]) ?? []), ...summaries] })
  const added = fresh.map((row) => ({ asset: String(row.id), alt: null }))
  emitItems(max.value === 1 ? added.slice(-1) : [...items.value, ...added].slice(0, max.value || undefined))
}

function remove(index: number) {
  emitItems(items.value.filter((_, position) => position !== index))
}

const confirm = useConfirm()
async function setAlt(index: number) {
  const item = items.value[index]
  const summary = known.value.get(item.asset)
  const result = await confirm({
    title: 'Alt Text',
    description: summary?.alt
      ? `Leave empty to use the asset's own: “${summary.alt}”`
      : 'Describe the image for people who can’t see it.',
    confirmText: 'Save',
    fields: [{ handle: 'alt', label: 'Alt text', options: [], value: item.alt ?? '' }],
  })
  if (!result) return
  emitItems(items.value.map((row, position) => (position === index ? { ...row, alt: result.alt || null } : row)))
}

const selectorOpen = ref(false)
const editingId = ref<number | null>(null)

const { rows: uploadRows, upload } = useUploads(
  () => folder.value,
  (asset) => add([asset]),
)
const fileInput = ref<HTMLInputElement | null>(null)
function onFileInput(event: Event) {
  const input = event.target as HTMLInputElement
  if (input.files?.length) upload(input.files)
  input.value = ''
}
const dragDepth = ref(0)
function hasFiles(event: DragEvent) {
  return !!event.dataTransfer?.types.includes('Files')
}
function onDrop(event: DragEvent) {
  dragDepth.value = 0
  if (!canUpload.value || !event.dataTransfer?.files.length) return
  const files = Array.from(event.dataTransfer.files).slice(0, room.value || undefined)
  if (files.length < event.dataTransfer.files.length) toast.error(`This field takes up to ${max.value}`)
  upload(files)
}
watch(
  uploadRows,
  (rows) => rows.filter((row) => row.status === 'error').forEach((row) => toast.error(`${row.name}: ${row.error}`)),
  {
    deep: true,
  },
)

const gridRef = useTemplateRef<HTMLElement>('grid')
useSortable(gridRef, items, {
  forceFallback: true,
  dragClass: 'sortable-drag-clone',
  ghostClass: 'sortable-ghost-placeholder',
  filter: 'button',
  preventOnFilter: false,
  onUpdate: () => queueMicrotask(() => emitItems([...items.value])),
})
</script>

<template>
  <div
    :id="id"
    data-asset-browser
    class="@container relative w-full rounded-xl bg-gray-50 dark:bg-transparent"
    @dragenter="(event) => canUpload && hasFiles(event) && dragDepth++"
    @dragleave="(event) => hasFiles(event) && (dragDepth = Math.max(0, dragDepth - 1))"
    @dragover.prevent
    @drop.prevent="onDrop"
  >
    <input ref="fileInput" class="hidden" type="file" :multiple="max !== 1" @change="onFileInput" />
    <div
      v-if="dragDepth > 0"
      class="absolute inset-0 z-10 flex items-center justify-center gap-2 rounded-lg border border-dashed border-gray-400 bg-white/80 text-gray-700"
    >
      <AdminIcon name="upload-cloud" class="size-5" />
      <span class="text-sm">Drop to Upload</span>
    </div>

    <div
      data-asset-picker
      class="flex flex-wrap items-center gap-x-3 gap-y-1 rounded-xl border border-gray-300 p-2 dark:border-gray-700 dark:bg-gray-850"
      :class="{ 'rounded-b-none': items.length }"
    >
      <Button
        v-if="canAdd"
        type="button"
        variant="outline"
        size="sm"
        aria-label="Browse Assets"
        class="shrink-0"
        @click="selectorOpen = true"
        ><AdminIcon name="folder" /><span class="@sm:hidden">Browse</span
        ><span class="hidden @sm:inline">Browse Assets</span></Button
      >
      <div
        v-if="canUpload"
        class="flex min-w-0 grow basis-[min-content] items-center gap-2 text-xs text-gray-600 dark:text-gray-400"
      >
        <AdminIcon name="upload-cloud" class="size-5 @max-sm:hidden" />
        <div class="min-w-0 whitespace-nowrap">
          <span class="hidden @sm:inline">Drag &amp; drop here or&nbsp;</span>
          <span class="@sm:hidden">or&nbsp;</span>
          <button
            type="button"
            class="cursor-pointer underline underline-offset-2 hover:text-gray-925 dark:hover:text-gray-200"
            @click="fileInput?.click()"
          >
            choose a file</button
          ><span class="hidden @sm:inline">.</span>
        </div>
      </div>
      <span v-if="uploadRows.some((row) => row.status === 'uploading')" class="text-xs text-gray-500">Uploading…</span>
      <Badge
        v-if="max"
        class="ms-auto px-1.25 font-mono text-2xs leading-normal"
        :aria-label="`${items.length}/${max} selected`"
        >{{ items.length }}/{{ max }}</Badge
      >
    </div>

    <div
      v-if="items.length"
      ref="grid"
      class="relative rounded-xl rounded-t-none border border-t-0 border-gray-300 bg-white p-3 dark:border-gray-700 dark:bg-gray-850"
      :class="
        listMode ? 'space-y-2' : 'grid gap-4 2xl:gap-10 @min-[300px]:grid-cols-[repeat(auto-fill,minmax(110px,1fr))]'
      "
    >
      <div
        v-for="(item, index) in items"
        :key="item.asset"
        :class="
          listMode
            ? 'flex items-center gap-3 rounded-lg border border-gray-200 p-1.5 dark:border-gray-700'
            : 'asset-tile'
        "
        :title="String(known.get(item.asset)?.filename ?? '')"
      >
        <div
          class="relative flex justify-center"
          :class="
            listMode
              ? 'size-10 shrink-0 overflow-hidden rounded-sm'
              : 'h-full w-full rounded-b-md @min-[300px]:border-b dark:border-gray-700'
          "
        >
          <div class="flex h-full flex-col items-center justify-center" :class="{ 'pb-1 @min-[300px]:p-1': !listMode }">
            <img
              v-if="known.get(item.asset)?.thumbnail"
              :src="known.get(item.asset)!.thumbnail as string"
              alt=""
              class="relative rounded-md"
              :class="{ 'size-10 object-cover': listMode }"
            />
            <FileIcon
              v-else
              :extension="extension(known.get(item.asset))"
              class="size-12"
              :class="{ 'size-8!': listMode }"
            />
          </div>
          <div
            v-if="!listMode"
            class="absolute inset-0 flex items-center justify-center opacity-0 duration-100 focus-within:opacity-100 hover:opacity-100"
          >
            <div class="flex items-center justify-center gap-2">
              <Button
                v-if="known.get(item.asset)"
                type="button"
                variant="outline"
                size="icon-sm"
                aria-label="Edit"
                @click="editingId = Number(item.asset)"
                ><AdminIcon name="edit"
              /></Button>
              <Button
                v-if="!isReadOnly"
                type="button"
                variant="outline"
                size="icon-sm"
                aria-label="Remove"
                @click="remove(index)"
                ><AdminIcon name="x"
              /></Button>
            </div>
          </div>
        </div>
        <div class="flex w-full items-center justify-between px-1">
          <div
            class="w-18 flex-1 truncate px-2 py-1 text-xs"
            :class="known.get(item.asset) ? 'text-gray-600 dark:text-gray-300' : 'text-red-600'"
          >
            {{ known.get(item.asset)?.filename ?? `Missing asset ${item.asset}` }}
          </div>
          <Badge
            v-if="altMode !== 'none' && known.get(item.asset)?.kind === 'image'"
            as="button"
            type="button"
            :variant="altMode === 'required' && !item.alt && !known.get(item.asset)?.alt ? 'destructive' : 'default'"
            class="rounded-[0.1875rem] px-1.25 text-2xs leading-normal"
            :class="{ 'border-sky-300 bg-sky-50 text-sky-700 dark:text-sky-300': !item.alt && altMode !== 'required' }"
            :disabled="isReadOnly"
            @click="setAlt(index)"
            >{{ item.alt ? 'Alt ✓' : 'Set Alt' }}</Badge
          >
          <template v-if="listMode">
            <Button
              v-if="known.get(item.asset)"
              type="button"
              variant="ghost"
              size="icon-sm"
              aria-label="Edit"
              @click="editingId = Number(item.asset)"
              ><AdminIcon name="edit"
            /></Button>
            <Button
              v-if="!isReadOnly"
              type="button"
              variant="ghost"
              size="icon-sm"
              aria-label="Remove"
              @click="remove(index)"
              ><AdminIcon name="x"
            /></Button>
          </template>
        </div>
      </div>
    </div>

    <AssetSelector
      v-model:open="selectorOpen"
      :max-files="room"
      :folder="folder"
      :restrict-folder="!!config.restrict"
      :allowed-types="allowedTypes"
      @select="add"
    />
    <AssetEditor :asset-id="editingId" @close="editingId = null" />
  </div>
</template>
