<script setup lang="ts">
import { computed, ref, watch } from 'vue'
import { Button } from '@/components/ui/button'
import { Sheet, SheetContent, SheetDescription, SheetTitle } from '@/components/ui/sheet'
import AssetBrowser, { type BrowseParams } from './AssetBrowser.vue'
import { browseUrl, request, type AssetRow, type BrowseResponse } from './api'

const props = withDefaults(
  defineProps<{
    maxFiles?: number
    folder?: string
    restrictFolder?: boolean
    allowedTypes?: string[]
    selected?: number[]
    title?: string
  }>(),
  { maxFiles: 0, folder: '', restrictFolder: false, allowedTypes: () => [], selected: () => [], title: '' },
)
const open = defineModel<boolean>('open', { required: true })
const emit = defineEmits<{ select: [rows: AssetRow[]] }>()

const data = ref<BrowseResponse | null>(null)
const params = ref<BrowseParams>({})
const selectedIds = ref<number[]>([])
const editingId = ref<number | null>(null)
const known = new Map<number, AssetRow>()

async function load() {
  const response = await request<BrowseResponse>(
    'GET',
    browseUrl({ ...params.value, types: props.allowedTypes.join(',') || null }),
  )
  response.listing.rows.forEach((row) => known.set(row.id, row))
  data.value = response
}

function navigate(next: BrowseParams) {
  const folder = next.folder
  if (
    props.restrictFolder &&
    typeof folder === 'string' &&
    props.folder &&
    folder !== props.folder &&
    !folder.startsWith(`${props.folder}/`)
  )
    next = { ...next, folder: props.folder }
  params.value = { ...params.value, ...next }
  load()
}

watch(open, (isOpen) => {
  if (!isOpen) return
  params.value = { folder: props.folder }
  selectedIds.value = []
  editingId.value = null
  load()
})

const count = computed(() => selectedIds.value.length)
function finish(rows: AssetRow[]) {
  emit('select', rows)
  open.value = false
}
</script>

<template>
  <Sheet v-model:open="open">
    <SheetContent :show-close-button="false" class="gap-0">
      <SheetTitle
        :class="
          title
            ? 'border-b px-4 py-3 text-base font-medium text-gray-900 dark:border-gray-700 dark:text-white'
            : 'sr-only'
        "
        >{{ title || 'Browse Assets' }}</SheetTitle
      >
      <SheetDescription class="sr-only">Choose assets for this field</SheetDescription>
      <div class="flex-1 overflow-y-auto px-4 pt-2">
        <AssetBrowser
          v-if="data"
          v-model:selected="selectedIds"
          v-model:editing-id="editingId"
          :data="data"
          mode="select"
          :max-files="maxFiles"
          @navigate="navigate"
          @changed="load"
          @pick="finish"
        />
      </div>
      <footer
        class="flex items-center justify-between border-t bg-gray-100 px-4 py-3 dark:border-gray-700 dark:bg-gray-900"
      >
        <span class="text-sm text-gray-700 dark:text-gray-300"
          ><span class="font-mono">{{ maxFiles ? `${count}/${maxFiles}` : count }}</span> selected</span
        >
        <div class="flex items-center gap-3">
          <Button variant="ghost" @click="open = false">Cancel</Button>
          <Button
            :disabled="!count"
            @click="finish(selectedIds.map((id) => known.get(id)).filter((row): row is AssetRow => !!row))"
            >Select</Button
          >
        </div>
      </footer>
    </SheetContent>
  </Sheet>
</template>
