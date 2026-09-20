<script setup lang="ts">
import { computed, ref } from 'vue'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'

type Point = { x: number; y: number }

const props = defineProps<{ src: string; value: Point | null; zoom: number }>()
const emit = defineEmits<{ cancel: []; finish: [point: Point | null, zoom: number] }>()

const x = ref(Math.round((props.value?.x ?? 0.5) * 100))
const y = ref(Math.round((props.value?.y ?? 0.5) * 100))
const z = ref(props.zoom || 1)
const position = computed(() => `${x.value}% ${y.value}%`)

function clampZoom(value: number) {
  return Math.min(10, Math.max(1, Math.round((Number(value) || 1) * 10) / 10))
}

function clamp(value: number) {
  return Math.min(100, Math.max(0, Math.round(Number(value) || 0)))
}

function pick(event: MouseEvent) {
  const box = (event.currentTarget as HTMLElement).getBoundingClientRect()
  x.value = clamp(((event.clientX - box.left) / box.width) * 100)
  y.value = clamp(((event.clientY - box.top) / box.height) * 100)
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
  <div class="focal-point z-20">
    <div
      class="focal-point-toolbox rounded-xl bg-white shadow-ui-md ring ring-gray-200 dark:bg-gray-850 dark:ring-gray-700/80"
    >
      <div class="p-6">
        <div class="flex items-center gap-2 text-lg font-medium text-gray-900 antialiased dark:text-white">
          Focal Point
        </div>
        <div class="text-sm tracking-tight text-pretty text-gray-600 dark:text-gray-400">
          Set a focal point to allow dynamic photo cropping with a subject that stays in frame.
        </div>
        <div class="focal-point-image" role="button" tabindex="0" aria-label="Pick the focal point" @click="pick">
          <img :src="src" alt="" />
          <div
            class="focal-point-reticle"
            :class="{ zoomed: z > 1 }"
            :style="{ left: `${x}%`, top: `${y}%`, width: `${100 / z}%`, aspectRatio: '1', translate: '-50% -50%' }"
          />
        </div>
      </div>
      <div class="mb-4 flex items-center justify-center text-sm">
        <div class="mx-2 flex items-center gap-1">
          <label class="me-1" for="focal-point-x">X</label>
          <Input
            id="focal-point-x"
            :model-value="x"
            type="number"
            min="0"
            max="100"
            class="w-20 font-mono"
            @update:model-value="(v) => (x = clamp(Number(v)))"
          />
          <span>%</span>
        </div>
        <div class="mx-2 flex items-center gap-1">
          <label class="me-1" for="focal-point-y">Y</label>
          <Input
            id="focal-point-y"
            :model-value="y"
            type="number"
            min="0"
            max="100"
            class="w-20 font-mono"
            @update:model-value="(v) => (y = clamp(Number(v)))"
          />
          <span>%</span>
        </div>
        <div class="mx-2 flex items-center gap-1">
          <label class="me-1" for="focal-point-z">Z</label>
          <Input
            id="focal-point-z"
            :model-value="z"
            type="number"
            min="1"
            max="10"
            step="0.1"
            class="w-20 font-mono"
            @update:model-value="(v) => (z = clampZoom(Number(v)))"
          />
        </div>
      </div>
      <div class="px-4">
        <input v-model.number="z" type="range" min="1" max="10" step="0.1" class="mb-4 w-full" aria-label="Zoom" />
      </div>
      <div class="mb-4 flex flex-wrap items-center justify-center gap-2 px-4">
        <Button variant="outline" @click="emit('cancel')">Cancel</Button>
        <Button variant="outline" @click="reset">Reset</Button>
        <Button @click="finish">Finish</Button>
      </div>
      <h6 class="rounded-b bg-gray-100 p-4 text-center dark:bg-gray-850">Crop previews are for example only</h6>
    </div>
    <div v-for="frame in 9" :key="frame" :class="`frame frame-${frame}`">
      <div
        class="frame-image"
        :style="{
          backgroundImage: `url(${JSON.stringify(src)})`,
          backgroundPosition: position,
          transform: `scale(${z})`,
          transformOrigin: position,
        }"
      />
    </div>
  </div>
</template>
