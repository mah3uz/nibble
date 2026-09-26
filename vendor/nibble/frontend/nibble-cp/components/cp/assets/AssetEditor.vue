<script setup lang="ts">
import { DialogContent, DialogDescription, DialogPortal, DialogRoot, DialogTitle } from 'reka-ui'
import { computed, onMounted, ref, watch } from 'vue'
import { toast } from 'vue-sonner'
import CpIcon from '@/components/cp/icons/CpIcon.vue'
import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import { DialogOverlay } from '@/components/ui/dialog'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { useConfirm } from '@/lib/confirm'
import { useLayerZIndex } from '@/lib/layers'
import { registerCoreFieldtypes } from '@nibble-cp/fieldtypes/core'
import { UPDATE_DEBOUNCE_MS } from '@nibble-cp/fieldtypes/useFieldtype'
import PublishContainer from '@nibble-cp/publish/PublishContainer.vue'
import PublishSections from '@nibble-cp/publish/PublishSections.vue'
import PublishTabs from '@nibble-cp/publish/PublishTabs.vue'
import { formatBytes, relativeTime, request, RequestError, type AssetDetail, type ImageEdits } from './api'
import type { AssetMenuAction } from './assetMenu'
import CropEditor from './CropEditor.vue'
import FileIcon from './FileIcon.vue'
import FocalPointEditor from './FocalPointEditor.vue'
import ReplacementPicker from './ReplacementPicker.vue'
import { useAssetActions } from './useAssetActions'

const props = defineProps<{
  assetId: number | null
  hasPrevious?: boolean
  hasNext?: boolean
}>()
const emit = defineEmits<{ close: []; previous: []; next: []; changed: [] }>()

registerCoreFieldtypes()

const open = computed(() => !!props.assetId)
const zIndex = useLayerZIndex(open)
const detail = ref<AssetDetail | null>(null)
const values = ref<Record<string, unknown>>({})
const meta = ref<Record<string, unknown>>({})
const focal = ref<{ x: number; y: number } | null>(null)
const tags = ref('')
const errors = ref<Record<string, string[]>>({})
const saving = ref(false)
const focusing = ref(false)
const cropping = ref(false)
const zoom = ref(1)
const edits = ref<ImageEdits>({})
const snapshot = ref('')

const asset = computed(() => detail.value?.asset ?? null)
const current = () => JSON.stringify([values.value, focal.value, zoom.value, edits.value, tags.value])
const dirty = computed(() => !!detail.value && current() !== snapshot.value)
const tabs = computed(() => detail.value?.blueprint.tabs ?? [])
const canFocus = computed(() => asset.value?.kind === 'image' && !!asset.value.thumbnail?.includes('/cp-thumb/'))

async function load(id: number) {
  const data = await request<AssetDetail>('GET', `/cp/media/${id}`)
  detail.value = data
  values.value = data.values
  meta.value = data.field_meta
  focal.value = data.asset.focal
  zoom.value = data.asset.focal_zoom
  edits.value = data.asset.edits
  tags.value = data.asset.tags.join(', ')
  errors.value = {}
  snapshot.value = current()
}
// fetch needs an absolute URL, which only exists client-side, so the initial load waits for mount.
onMounted(() => props.assetId && load(props.assetId))
watch(
  () => props.assetId,
  (id) => (id ? load(id) : (detail.value = null)),
)

const confirm = useConfirm()
async function leave(then: () => void) {
  if (dirty.value && !(await confirm({ title: 'Discard your changes?', confirmText: 'Discard', dangerous: true })))
    return
  then()
}

async function save() {
  if (!asset.value) return
  saving.value = true
  await new Promise((resolve) => setTimeout(resolve, UPDATE_DEBOUNCE_MS))
  try {
    await request('PATCH', `/cp/media/${asset.value.id}`, {
      asset: {
        ...values.value,
        focal_x: focal.value?.x ?? null,
        focal_y: focal.value?.y ?? null,
        focal_zoom: zoom.value,
        edits: edits.value,
        tags: tags.value
          .split(',')
          .map((tag) => tag.trim())
          .filter(Boolean),
        lock_version: asset.value.lock_version,
      },
    })
    toast.success('Saved')
    await load(asset.value.id)
    emit('changed')
  } catch (error) {
    if (error instanceof RequestError && error.body.errors) errors.value = error.body.errors as Record<string, string[]>
    toast.error((error as Error).message)
  } finally {
    saving.value = false
  }
}

const replacementPicker = ref<InstanceType<typeof ReplacementPicker> | null>(null)
function applyCrop(next: ImageEdits) {
  edits.value = next
  cropping.value = false
  save()
}

async function saveCopy(next: ImageEdits) {
  if (!asset.value) return
  try {
    await request('POST', `/cp/media/${asset.value.id}/duplicate`, { asset: { edits: next } })
    toast.success('Saved as a copy')
    cropping.value = false
    emit('changed')
  } catch (error) {
    toast.error((error as Error).message)
  }
}

const actions = useAssetActions({
  folderOptions: () => detail.value?.folder_options ?? [],
  changed: () => {
    emit('changed')
    if (props.assetId) load(props.assetId)
  },
  edit: () => {},
  deleted: () => emit('close'),
  pickReplacement: () => replacementPicker.value?.pick() ?? Promise.resolve(null),
})
function run(action: AssetMenuAction) {
  if (asset.value) actions.run(action, asset.value)
}
</script>

<template>
  <DialogRoot :open="open" @update:open="(value) => !value && leave(() => emit('close'))">
    <DialogPortal>
      <DialogOverlay :style="{ zIndex }" />
      <DialogContent
        class="fixed inset-2 flex flex-col overflow-hidden rounded-xl shadow-[0_5px_20px_rgba(0,0,0,.3)] outline-none"
        :style="{ zIndex: zIndex + 1 }"
        @escape-key-down="(event) => (focusing || cropping) && event.preventDefault()"
      >
        <DialogTitle class="sr-only">{{ asset?.filename ?? 'Asset' }}</DialogTitle>
        <DialogDescription class="sr-only">Edit the asset's details</DialogDescription>
        <div class="asset-editor relative flex h-full flex-col rounded-sm bg-gray-100 dark:bg-gray-850">
          <header class="relative flex w-full justify-between px-2">
            <a
              v-if="asset"
              :href="asset.url"
              target="_blank"
              rel="noopener"
              class="group flex items-center gap-2 p-4 sm:gap-3"
              aria-label="Open in a new window"
            >
              <CpIcon name="folder-photos" class="size-5" />
              <span
                class="text-sm group-hover:text-ui-accent-text/80 dark:text-gray-400 dark:group-hover:text-gray-200"
                >{{ asset.filename }}</span
              >
            </a>
            <span v-else />
            <Button variant="ghost" size="icon" aria-label="Close Editor" @click="leave(() => emit('close'))"
              ><CpIcon name="x"
            /></Button>
          </header>

          <div v-if="detail && asset" class="flex flex-1 grow flex-col overflow-auto md:flex-row md:justify-between">
            <div
              class="editor-preview flex min-h-[45vh] w-full flex-1 flex-col justify-between bg-gray-800 shadow-[inset_0px_4px_3px_0px_black] md:min-h-auto md:w-1/2 md:flex-auto md:grow md:rounded-se-xl lg:w-2/3 dark:bg-gray-900"
            >
              <div class="dark flex flex-wrap items-center justify-center gap-2 px-2 py-4">
                <Button v-if="canFocus && detail.can.edit" variant="ghost" size="sm" @click="focusing = true"
                  ><CpIcon name="focus" /> Focal Point</Button
                >
                <Button v-if="canFocus && detail.can.edit" variant="ghost" size="sm" @click="cropping = true"
                  ><CpIcon name="crop" /> Crop</Button
                >
                <Button v-if="detail.can.edit" variant="ghost" size="sm" @click="run('rename')"
                  ><CpIcon name="rename" /> Rename</Button
                >
                <Button v-if="detail.can.edit" variant="ghost" size="sm" @click="run('move')"
                  ><CpIcon name="move-folder" /> Move to Folder</Button
                >
                <Button v-if="detail.can.edit" variant="ghost" size="sm" @click="run('replace')"
                  ><CpIcon name="replace" /> Replace</Button
                >
                <Button v-if="detail.can.edit" variant="ghost" size="sm" @click="run('reupload')"
                  ><CpIcon name="upload-cloud" /> Reupload</Button
                >
                <Button variant="ghost" size="sm" as-child
                  ><a :href="asset.download_url"><CpIcon name="download" /> Download</a></Button
                >
                <Button v-if="detail.can.delete" variant="ghost" size="sm" @click="run('delete')"
                  ><CpIcon name="trash" /> Delete</Button
                >
              </div>
              <div class="flex h-full min-h-0 flex-1 flex-col items-center justify-center p-8">
                <img
                  v-if="asset.kind === 'image' || asset.kind === 'svg'"
                  :src="asset.preview"
                  :alt="asset.alt ?? ''"
                  class="relative max-h-full max-w-full object-contain shadow-ui-xl"
                />
                <video v-else-if="asset.kind === 'video'" :src="asset.url" controls class="max-h-full max-w-full" />
                <audio v-else-if="asset.kind === 'audio'" :src="asset.url" controls class="w-full max-w-md" />
                <object
                  v-else-if="asset.extension === 'pdf'"
                  :data="asset.url"
                  type="application/pdf"
                  class="size-full rounded-md"
                />
                <FileIcon v-else :extension="asset.extension" class="size-32" />
              </div>
            </div>

            <div class="h-1/2 w-full overflow-scroll sm:p-4 md:h-full md:w-1/3 md:grow md:pt-px">
              <PublishContainer
                :model-value="values"
                :blueprint="detail.blueprint"
                :meta="meta"
                :errors="errors"
                :read-only="!detail.can.edit"
                name="asset"
                @update:model-value="(next) => (values = next)"
                @update:meta="(next) => (meta = next)"
              >
                <PublishTabs v-if="tabs.length > 1" :tabs="tabs" />
                <PublishSections v-else-if="tabs.length" :sections="tabs[0].sections" />
              </PublishContainer>

              <div
                class="relative mb-6 w-full rounded-2xl bg-gray-150 p-1.75 max-[600px]:p-1.25 dark:bg-gray-950/35 dark:inset-shadow-2xs dark:inset-shadow-black"
              >
                <div
                  class="space-y-5 rounded-xl bg-white px-4 py-5 shadow-ui-md ring ring-gray-200 sm:px-4.5 dark:bg-gray-850 dark:ring-gray-700/80"
                >
                  <div class="flex flex-col gap-2">
                    <Label for="asset-tags">Tags</Label>
                    <Input
                      id="asset-tags"
                      v-model="tags"
                      :disabled="!detail.can.edit"
                      placeholder="Separate tags with commas"
                    />
                  </div>
                  <div class="flex flex-col gap-2">
                    <span class="text-sm font-medium text-gray-925 dark:text-gray-300">{{
                      detail.usage.length
                        ? `Used in ${detail.usage.length} ${detail.usage.length === 1 ? 'place' : 'places'}`
                        : 'Not used anywhere'
                    }}</span>
                    <ul v-if="detail.usage.length" class="space-y-1 text-sm">
                      <li
                        v-for="use in detail.usage"
                        :key="`${use.type}-${use.edit_url}`"
                        class="flex items-center justify-between gap-2"
                      >
                        <a v-if="use.edit_url" :href="use.edit_url" class="truncate hover:underline">{{ use.title }}</a>
                        <span v-else class="truncate">{{ use.title }}</span>
                        <span class="shrink-0 text-xs text-gray-500">{{ use.type }} · {{ use.field }}</span>
                      </li>
                    </ul>
                  </div>
                </div>
              </div>
            </div>
          </div>
          <div v-else class="flex-1" />

          <div
            class="flex w-full items-center justify-end rounded-b border-t bg-gray-100 px-4 py-3 dark:border-gray-700 dark:bg-gray-900"
          >
            <div v-if="asset" class="hidden h-full flex-1 gap-2 py-1 sm:flex sm:gap-3">
              <Badge v-if="asset.width"
                ><CpIcon name="assets" class="size-3.5 opacity-60" /> {{ asset.width }} × {{ asset.height }}</Badge
              >
              <Badge><CpIcon name="memory" class="size-3.5 opacity-60" /> {{ formatBytes(asset.size) }}</Badge>
              <Badge
                ><CpIcon name="fingerprint" class="size-3.5 opacity-60" />
                <time :datetime="asset.updated_at">{{ relativeTime(asset.updated_at) }}</time></Badge
              >
            </div>
            <div class="flex items-center space-x-3">
              <Button
                variant="outline"
                size="icon"
                aria-label="Previous asset"
                :disabled="!hasPrevious"
                @click="leave(() => emit('previous'))"
                ><CpIcon name="chevron-left"
              /></Button>
              <Button
                variant="outline"
                size="icon"
                aria-label="Next asset"
                :disabled="!hasNext"
                @click="leave(() => emit('next'))"
                ><CpIcon name="chevron-right"
              /></Button>
              <Button variant="outline" @click="leave(() => emit('close'))">Close</Button>
              <Button v-if="detail?.can.edit" :disabled="saving" @click="save"><CpIcon name="save" /> Save</Button>
            </div>
          </div>

          <ReplacementPicker ref="replacementPicker" />
          <FocalPointEditor
            v-if="focusing && asset"
            :src="asset.preview"
            :value="focal"
            :zoom="zoom"
            @cancel="focusing = false"
            @finish="
              (point, level) => {
                focal = point
                zoom = level
                focusing = false
              }
            "
          />
          <CropEditor
            v-if="cropping && asset"
            :src="asset.url"
            :edits="edits"
            @cancel="cropping = false"
            @apply="applyCrop"
            @copy="saveCopy"
          />
        </div>
      </DialogContent>
    </DialogPortal>
  </DialogRoot>
</template>
