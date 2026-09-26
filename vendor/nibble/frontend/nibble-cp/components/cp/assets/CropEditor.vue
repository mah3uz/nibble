<script setup lang="ts">
import { FlipHorizontal2, FlipVertical2, RotateCcw, RotateCw } from '@lucide/vue'
import { nextTick, onMounted, ref, useTemplateRef, watch } from 'vue'
import { Button } from '@/components/ui/button'
import type { ImageEdits } from './api'

type Box = { x: number; y: number; width: number; height: number }
type Selection = HTMLElement & { aspectRatio: number; $change: (x: number, y: number, w: number, h: number) => void }

const props = defineProps<{ src: string; edits: ImageEdits }>()
const emit = defineEmits<{ cancel: []; apply: [edits: ImageEdits]; copy: [edits: ImageEdits] }>()

const ASPECTS: [string, number | 'original' | null][] = [
  ['Free', null],
  ['Original', 'original'],
  ['Square', 1],
  ['4:3', 4 / 3],
  ['3:2', 3 / 2],
  ['16:9', 16 / 9],
]
const PREVIEW_MAX = 1600
// A selection that starts smaller than the image shows at once what can be dragged and resized.
const STARTING_SIZE = 0.8

const ready = ref(false)
const preview = ref<string | null>(null)
const renders = ref(0)
const size = ref({ width: 1, height: 1 })
const rotate = ref(props.edits.rotate ?? 0)
const flip = ref<ImageEdits['flip'] | null>(props.edits.flip ?? null)
const crop = ref<Box | null>(props.edits.crop ?? null)
const aspect = ref<number | 'original' | null>(null)
const canvasEl = useTemplateRef<HTMLElement>('canvas')
const imageEl = useTemplateRef<HTMLElement & { $ready: () => Promise<unknown> }>('image')
const selectionEl = useTemplateRef<Selection>('selection')
let source: HTMLImageElement | null = null

function render() {
  if (!source) return
  const scale = Math.min(1, PREVIEW_MAX / Math.max(source.naturalWidth, source.naturalHeight))
  const width = Math.round(source.naturalWidth * scale)
  const height = Math.round(source.naturalHeight * scale)
  const turned = rotate.value % 180 !== 0
  const canvas = document.createElement('canvas')
  canvas.width = turned ? height : width
  canvas.height = turned ? width : height
  const context = canvas.getContext('2d')!
  context.translate(canvas.width / 2, canvas.height / 2)
  context.scale(flip.value === 'horizontal' ? -1 : 1, flip.value === 'vertical' ? -1 : 1)
  context.rotate((rotate.value * Math.PI) / 180)
  context.drawImage(source, -width / 2, -height / 2, width, height)
  size.value = { width: canvas.width, height: canvas.height }
  preview.value = canvas.toDataURL('image/jpeg', 0.92)
  renders.value += 1
}

function imageRect() {
  const bounds = canvasEl.value!.getBoundingClientRect()
  const scale = Math.min(bounds.width / size.value.width, bounds.height / size.value.height)
  const width = size.value.width * scale
  const height = size.value.height * scale
  return { x: (bounds.width - width) / 2, y: (bounds.height - height) / 2, width, height }
}

function ratio() {
  return aspect.value === 'original' ? size.value.width / size.value.height : aspect.value
}

function place() {
  const selection = selectionEl.value
  if (!selection) return
  const rect = imageRect()
  const wanted = ratio()
  selection.aspectRatio = wanted ?? NaN
  if (crop.value && !wanted) {
    const box = crop.value
    return selection.$change(
      rect.x + box.x * rect.width,
      rect.y + box.y * rect.height,
      box.width * rect.width,
      box.height * rect.height,
    )
  }
  let width = rect.width * STARTING_SIZE
  let height = rect.height * STARTING_SIZE
  if (wanted) {
    if (width / height > wanted) width = height * wanted
    else height = width / wanted
  }
  selection.$change(rect.x + (rect.width - width) / 2, rect.y + (rect.height - height) / 2, width, height)
}

function onChange(event: Event) {
  const { x, y, width, height } = (event as CustomEvent<Box>).detail
  const rect = imageRect()
  const slack = 0.5
  if (
    x < rect.x - slack ||
    y < rect.y - slack ||
    x + width > rect.x + rect.width + slack ||
    y + height > rect.y + rect.height + slack
  )
    return event.preventDefault()
  crop.value = {
    x: Math.max(0, (x - rect.x) / rect.width),
    y: Math.max(0, (y - rect.y) / rect.height),
    width: Math.min(1, width / rect.width),
    height: Math.min(1, height / rect.height),
  }
}

watch(preview, async () => {
  await nextTick()
  await imageEl.value?.$ready()
  place()
})

function turn(degrees: number) {
  rotate.value = (rotate.value + degrees + 360) % 360
  crop.value = null
  render()
}

function mirror(direction: 'horizontal' | 'vertical') {
  if (flip.value === direction) flip.value = null
  else if (flip.value) {
    flip.value = null
    rotate.value = (rotate.value + 180) % 360
  } else flip.value = direction
  crop.value = null
  render()
}

function choose(value: number | 'original' | null) {
  aspect.value = value
  crop.value = null
  place()
}

function reset() {
  rotate.value = 0
  flip.value = null
  crop.value = null
  aspect.value = null
  render()
}

function result(): ImageEdits {
  const box = crop.value
  const whole = !box || (box.x < 0.001 && box.y < 0.001 && box.width > 0.999 && box.height > 0.999)
  return {
    ...(whole ? {} : { crop: box! }),
    ...(rotate.value ? { rotate: rotate.value } : {}),
    ...(flip.value ? { flip: flip.value } : {}),
  }
}

onMounted(async () => {
  const elements = await import('cropperjs')
  for (const element of [
    elements.CropperCanvas,
    elements.CropperImage,
    elements.CropperShade,
    elements.CropperHandle,
    elements.CropperSelection,
  ])
    element.$define()
  source = new Image()
  source.src = props.src
  await source.decode()
  ready.value = true
  render()
})
</script>

<template>
  <div class="absolute inset-0 z-20 flex flex-col bg-gray-800 dark:bg-gray-900">
    <div class="dark flex flex-wrap items-center justify-center gap-2 px-2 py-4">
      <Button
        v-for="[label, value] in ASPECTS"
        :key="label"
        variant="ghost"
        size="sm"
        :aria-pressed="aspect === value"
        :class="{ 'bg-white/10': aspect === value }"
        @click="choose(value)"
        >{{ label }}</Button
      >
      <span class="mx-2 h-5 w-px bg-white/15" />
      <Button variant="ghost" size="sm" aria-label="Rotate left" @click="turn(-90)"><RotateCcw /></Button>
      <Button variant="ghost" size="sm" aria-label="Rotate right" @click="turn(90)"><RotateCw /></Button>
      <Button
        variant="ghost"
        size="sm"
        aria-label="Flip horizontally"
        :aria-pressed="flip === 'horizontal'"
        @click="mirror('horizontal')"
        ><FlipHorizontal2
      /></Button>
      <Button
        variant="ghost"
        size="sm"
        aria-label="Flip vertically"
        :aria-pressed="flip === 'vertical'"
        @click="mirror('vertical')"
        ><FlipVertical2
      /></Button>
      <Button variant="ghost" size="sm" @click="reset">Reset</Button>
    </div>
    <div class="min-h-0 flex-1 p-8">
      <cropper-canvas v-if="ready && preview" :key="renders" ref="canvas" background class="block size-full">
        <cropper-image ref="image" :src="preview" initial-center-size="contain" alt="" />
        <cropper-shade theme-color="rgba(0, 0, 0, 0.6)" />
        <cropper-selection ref="selection" movable resizable outlined @change="onChange">
          <div class="crop-guides" aria-hidden="true" />
          <cropper-handle action="move" plain />
          <cropper-handle
            v-for="action in ['n', 'e', 's', 'w', 'ne', 'nw', 'se', 'sw']"
            :key="action"
            :action="`${action}-resize`"
          />
        </cropper-selection>
      </cropper-canvas>
    </div>
    <div class="flex items-center justify-end gap-3 border-t border-gray-700 px-4 py-3">
      <Button variant="ghost" class="dark text-gray-300" @click="emit('cancel')">Cancel</Button>
      <Button variant="outline" @click="emit('copy', result())">Save as copy</Button>
      <Button @click="emit('apply', result())">Apply</Button>
    </div>
  </div>
</template>
