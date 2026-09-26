<script setup lang="ts">
import { computed, ref } from 'vue'
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
  w >= h ? { aspectRatio: `${w} / ${h}`, width: '100%' } : { aspectRatio: `${w} / ${h}`, height: '14rem' }

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
    <aside
      class="flex w-[380px] shrink-0 flex-col border-e border-gray-200 bg-white dark:border-gray-800 dark:bg-gray-900"
    >
      <div class="flex-1 space-y-5 overflow-y-auto p-6">
        <div>
          <h2 class="text-lg font-medium text-gray-900 dark:text-white">Focal Point</h2>
          <p class="mt-1 text-sm text-pretty text-gray-600 dark:text-gray-400">
            Drag to the part of the image that has to stay in frame. Crops of any shape keep it in view.
          </p>
        </div>

        <div
          class="focal-picker relative cursor-crosshair touch-none overflow-hidden rounded-lg ring-1 ring-gray-200 outline-none select-none focus-visible:ring-2 focus-visible:ring-primary dark:ring-gray-700"
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
          <img :src="src" alt="" class="block w-full" draggable="false" />
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
        <p class="text-xs text-gray-500 dark:text-gray-400">Arrow keys move the point; hold Shift for bigger steps.</p>
      </div>

      <div class="flex items-center justify-end gap-2 border-t border-gray-200 px-6 py-4 dark:border-gray-800">
        <Button variant="ghost" class="me-auto" @click="reset">Reset</Button>
        <Button variant="outline" @click="emit('cancel')">Cancel</Button>
        <Button @click="finish">Finish</Button>
      </div>
    </aside>

    <section class="flex min-w-0 flex-1 flex-col overflow-y-auto p-6">
      <div class="mb-5">
        <h3 class="text-sm font-medium text-gray-900 dark:text-white">How it crops</h3>
        <p class="text-sm text-gray-600 dark:text-gray-400">
          Examples only: a theme chooses its own sizes, and each keeps the focal point in view.
        </p>
      </div>
      <div class="grid grid-cols-[repeat(auto-fill,minmax(220px,1fr))] items-end gap-6">
        <figure v-for="frame in FRAMES" :key="frame.label" class="space-y-2">
          <div
            class="mx-auto overflow-hidden rounded-lg bg-gray-200 shadow-ui-sm ring-1 ring-gray-200 dark:bg-gray-800 dark:ring-gray-700"
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
    </section>
  </div>
</template>
