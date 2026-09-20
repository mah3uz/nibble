<script setup lang="ts">
import { NodeViewWrapper, nodeViewProps } from '@tiptap/vue-3'
import { computed, nextTick, ref } from 'vue'
import type { AssetRow } from '@/components/admin/assets/api'
import AssetSelector from '@/components/admin/assets/AssetSelector.vue'
import { resolvePickedAlt } from '@/components/admin/assets/pickedAssetAlt'
import AdminIcon from '@/components/admin/icons/AdminIcon.vue'
import { Button } from '@/components/ui/button'
import { InputGroup, InputGroupAddon, InputGroupInput, InputGroupText } from '@/components/ui/input-group'

const props = defineProps(nodeViewProps)

const pickerOpen = ref(false)
const altInput = ref<InstanceType<typeof InputGroupInput> | null>(null)
const missingAlt = computed(() => !String(props.node.attrs.alt ?? '').trim())
const showingAlt = ref(missingAlt.value)

const alt = computed({
  get: () => props.node.attrs.alt ?? '',
  set: (value: string) => props.updateAttributes({ alt: value }),
})

async function toggleAlt() {
  showingAlt.value = !showingAlt.value
  if (!showingAlt.value) return
  await nextTick()
  ;(altInput.value?.$el as HTMLInputElement | undefined)?.focus()
}

function replace([asset]: AssetRow[]) {
  if (!asset) return
  props.updateAttributes({
    src: asset.url,
    asset: String(asset.id),
    width: asset.width,
    height: asset.height,
    alt: resolvePickedAlt(alt.value, asset.alt ?? ''),
  })
}
</script>

<template>
  <NodeViewWrapper>
    <div
      :class="['nib-image shadow-xs', selected ? 'border-blue-400' : 'border-gray-200 dark:border-gray-600']"
      contenteditable="false"
    >
      <div class="p-2 text-center" draggable="true" data-drag-handle>
        <img :src="node.attrs.src" :alt="node.attrs.alt" class="block h-auto w-full rounded-xs" />
      </div>
      <div
        class="flex flex-wrap items-center justify-center gap-2 border-t border-gray-200 px-2 py-2 text-center dark:border-gray-900"
      >
        <Button
          type="button"
          size="sm"
          variant="outline"
          :class="{ 'bg-gray-100 to-gray-100 dark:bg-gray-800': showingAlt }"
          @mousedown.prevent
          @click="toggleAlt"
        >
          <AdminIcon name="rename" class="size-3" />Override Alt
        </Button>
        <Button type="button" size="sm" variant="outline" @mousedown.prevent @click="pickerOpen = true">
          <AdminIcon name="replace" class="size-3" />Replace
        </Button>
        <Button type="button" size="sm" variant="outline" @mousedown.prevent @click="deleteNode">
          <AdminIcon name="trash" class="size-3" />Remove
        </Button>
      </div>
      <div
        v-if="showingAlt"
        class="flex flex-col gap-1 rounded-b border-t border-gray-200 p-2 dark:border-gray-900"
        @paste.stop
      >
        <InputGroup
          :data-invalid="missingAlt || undefined"
          class="h-10 border-gray-300 bg-white shadow-ui-sm focus-within:focus-outline has-[[data-slot=input-group-control]:focus-visible]:border-gray-300 has-[[data-slot=input-group-control]:focus-visible]:ring-0 dark:border-gray-700 dark:bg-gray-900"
        >
          <InputGroupAddon><InputGroupText>Alt Text</InputGroupText></InputGroupAddon>
          <InputGroupInput
            ref="altInput"
            v-model="alt"
            class="h-full focus-visible:outline-none"
            placeholder="What the image shows"
            :aria-invalid="missingAlt || undefined"
            aria-label="Alt text"
          />
        </InputGroup>
        <p v-if="missingAlt" class="text-start text-xs text-red-600">Alt text is required.</p>
      </div>
    </div>
    <AssetSelector
      v-model:open="pickerOpen"
      :max-files="1"
      :allowed-types="['jpg', 'jpeg', 'png', 'gif', 'webp', 'avif', 'svg']"
      @select="replace"
    />
  </NodeViewWrapper>
</template>
