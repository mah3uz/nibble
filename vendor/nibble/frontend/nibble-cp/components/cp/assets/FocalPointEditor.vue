<script setup lang="ts">
import { useElementSize } from '@vueuse/core'
import { computed, ref, useTemplateRef } from 'vue'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'

type Point = { x: number; y: number }

const props = defineProps<{ src: string; value: Point | null; zoom: number }>()
const emit = defineEmits<{ cancel: []; finish: [point: Point | null, zoom: number] }>()

const FRAMES = [
  { label: 'Wide banner', ratio: [21, 9] },
  { label: 'Landscape', ratio: [16, 9] },
  { label: 'Card', ratio: [4, 3] },
  { label: 'Square', ratio: [1, 1] },
  { label: 'Portrait', ratio: [3, 4] },
  { label: 'Story', ratio: [9, 16] },
]

// Wide frames fill the column; tall ones take a fixed height, so none overflows or towers over the rest.
const frameSize = ([w, h]: number[]) =>
  w >= h ? { aspectRatio: `${w} / ${h}`, width: '100%' } : { aspectRatio: `${w} / ${h}`, height: '9rem' }

// The picker is the work surface, so it takes the largest size the stage allows at the image's own proportions.
const stage = useTemplateRef<HTMLElement>('stage')
const { width: stageWidth, height: stageHeight } = useElementSize(stage)
const natural = ref({ width: 0, height: 0 })
const fitted = computed(() => {
  const { width, height } = natural.value
  if (!width || !height || !stageWidth.value || !stageHeight.value) return {}
  const scale = Math.min(stageWidth.value / width, stageHeight.value / height)
  return { width: `${Math.floor(width * scale)}px`, height: `${Math.floor(height * scale)}px` }
})

function measure(event: Event) {
  const image = event.target as HTMLImageElement
  natural.value = { width: image.naturalWidth, height: image.naturalHeight }
}

const x = ref(Math.round((props.value?.x ?? 0.5) * 100))
const y = ref(Math.round((props.value?.y ?? 0.5) * 100))
const z = ref(props.zoom || 1)
const dragging = ref(false)
const position = computed(() => `${x.value}% ${y.value}%`)

const clamp = (value: number) => Math.min(100, Math.max(0, Math.round(Number(value) || 0)))
const clampZoom = (value: number) => Math.min(10, Math.max(1, Math.round((Number(value) || 1) * 10) / 10))

function pick(event: PointerEvent) {
  const box = (event.currentTarget as HTMLElement).getBoundingClientRect()
  x.value = clamp(((event.clientX - box.left) / box.width) * 100)
  y.value = clamp(((event.clientY - box.top) / box.height) * 100)
}

function start(event: PointerEvent) {
  dragging.value = true
  ;(event.currentTarget as HTMLElement).setPointerCapture(event.pointerId)
  pick(event)
}

function nudge(event: KeyboardEvent) {
  const step = event.shiftKey ? 10 : 1
  const moves: Record<string, [number, number]> = {
    ArrowLeft: [-step, 0],
    ArrowRight: [step, 0],
    ArrowUp: [0, -step],
    ArrowDown: [0, step],
  }
  const move = moves[event.key]
  if (!move) return
  event.preventDefault()
  x.value = clamp(x.value + move[0])
  y.value = clamp(y.value + move[1])
}

function reset() {
  x.value = 50
  y.value = 50
  z.value = 1
}

function finish() {
  emit('finish', x.value === 50 && y.value === 50 ? null : { x: x.value / 100, y: y.value / 100 }, z.value)
}
</script>

<template>
  <div class="absolute inset-0 z-20 flex bg-gray-100 dark:bg-gray-950">
    <section class="flex min-w-0 flex-1 flex-col gap-4 p-6">
      <div class="flex flex-wrap items-baseline justify-between gap-x-6 gap-y-1">
        <div>
          <h2 class="text-lg font-medium text-gray-900 dark:text-white">Focal Point</h2>
          <p class="text-sm text-pretty text-gray-600 dark:text-gray-400">
            Drag to the part of the image that has to stay in frame. Crops of any shape keep it in view.
          </p>
        </div>
        <p class="text-xs text-gray-500 dark:text-gray-400">Arrow keys move the point; hold Shift for bigger steps.</p>
      </div>

      <div ref="stage" class="flex min-h-0 flex-1 items-center justify-center">
        <div
          class="relative cursor-crosshair touch-none overflow-hidden rounded-lg shadow-ui-md ring-1 ring-gray-200 outline-none select-none focus-visible:ring-2 focus-visible:ring-primary dark:ring-gray-700"
          :style="fitted"
          role="slider"
          tabindex="0"
          aria-label="Focal point"
          :aria-valuetext="`${x}% across, ${y}% down`"
          @pointerdown="start"
          @pointermove="dragging && pick($event)"
          @pointerup="dragging = false"
          @pointercancel="dragging = false"
          @keydown="nudge"
        >
          <img :src="src" alt="" class="block size-full" draggable="false" @load="measure" />
          <div
            v-if="z > 1"
            class="focal-zoom"
            :style="{ left: `${x}%`, top: `${y}%`, width: `${100 / z}%` }"
            aria-hidden="true"
          />
          <div
            class="focal-marker"
            :class="{ 'transition-[left,top] duration-200': !dragging }"
            :style="{ left: `${x}%`, top: `${y}%` }"
            aria-hidden="true"
          />
        </div>
      </div>
    </section>

    <aside
      class="flex w-[400px] shrink-0 flex-col border-s border-gray-200 bg-white dark:border-gray-800 dark:bg-gray-900"
    >
      <div class="space-y-4 border-b border-gray-200 p-5 dark:border-gray-800">
        <div class="grid grid-cols-3 gap-3">
          <div class="space-y-1.5">
            <Label for="focal-point-x">Across</Label>
            <div class="relative">
              <Input
                id="focal-point-x"
                :model-value="x"
                type="number"
                min="0"
                max="100"
                class="pe-7 font-mono"
                @update:model-value="(v) => (x = clamp(Number(v)))"
              />
              <span class="pointer-events-none absolute inset-y-0 end-2.5 flex items-center text-sm text-gray-500"
                >%</span
              >
            </div>
          </div>
          <div class="space-y-1.5">
            <Label for="focal-point-y">Down</Label>
            <div class="relative">
              <Input
                id="focal-point-y"
                :model-value="y"
                type="number"
                min="0"
                max="100"
                class="pe-7 font-mono"
                @update:model-value="(v) => (y = clamp(Number(v)))"
              />
              <span class="pointer-events-none absolute inset-y-0 end-2.5 flex items-center text-sm text-gray-500"
                >%</span
              >
            </div>
          </div>
          <div class="space-y-1.5">
            <Label for="focal-point-z">Zoom</Label>
            <div class="relative">
              <Input
                id="focal-point-z"
                :model-value="z"
                type="number"
                min="1"
                max="10"
                step="0.1"
                class="pe-7 font-mono"
                @update:model-value="(v) => (z = clampZoom(Number(v)))"
              />
              <span class="pointer-events-none absolute inset-y-0 end-2.5 flex items-center text-sm text-gray-500"
                >×</span
              >
            </div>
          </div>
        </div>
        <input
          v-model.number="z"
          type="range"
          min="1"
          max="10"
          step="0.1"
          class="w-full accent-primary"
          aria-label="Zoom"
        />
      </div>

      <div class="min-h-0 flex-1 overflow-y-auto p-5">
        <h3 class="text-sm font-medium text-gray-900 dark:text-white">How it crops</h3>
        <p class="mb-4 text-xs text-gray-600 dark:text-gray-400">
          Examples only: a theme chooses its own sizes, and each keeps the focal point in view.
        </p>
        <div class="grid grid-cols-2 items-end gap-x-4 gap-y-5">
          <figure v-for="frame in FRAMES" :key="frame.label" class="space-y-1.5">
            <div
              class="mx-auto overflow-hidden rounded-md bg-gray-200 ring-1 ring-gray-200 dark:bg-gray-800 dark:ring-gray-700"
              :style="frameSize(frame.ratio)"
            >
              <div
                class="size-full bg-cover transition-[background-position,transform] duration-300"
                :style="{
                  backgroundImage: `url(${JSON.stringify(src)})`,
                  backgroundPosition: position,
                  transform: `scale(${z})`,
                  transformOrigin: position,
                }"
              />
            </div>
            <figcaption class="text-center text-xs text-gray-600 dark:text-gray-400">
              {{ frame.label }} <span class="text-gray-400 dark:text-gray-500">{{ frame.ratio.join(':') }}</span>
            </figcaption>
          </figure>
        </div>
      </div>

      <div class="flex items-center justify-end gap-2 border-t border-gray-200 px-5 py-4 dark:border-gray-800">
        <Button variant="ghost" class="me-auto" @click="reset">Reset</Button>
        <Button variant="outline" @click="emit('cancel')">Cancel</Button>
        <Button @click="finish">Finish</Button>
      </div>
    </aside>
  </div>
</template>
