<script setup lang="ts">
import { useElementSize } from '@vueuse/core'
import { computed, ref, useId, useTemplateRef } from 'vue'
import { dayLabels, niceMax, smoothPath, type Point } from '@/lib/chart'

export type Series = { key: string; label: string; values: number[]; color: string; dot: string }

const props = defineProps<{ series: Series[]; start: string }>()

const HEIGHT = 208
const PAD = { top: 12, right: 8, bottom: 26, left: 32 }
const id = useId()
const box = useTemplateRef<HTMLElement>('box')
const { width } = useElementSize(box)
const hover = ref<number | null>(null)

const count = computed(() => props.series[0]?.values.length ?? 0)
const labels = computed(() => dayLabels(props.start, count.value))
const longLabels = computed(() =>
  dayLabels(props.start, count.value, { weekday: 'short', month: 'short', day: 'numeric' }),
)
const max = computed(() => niceMax(Math.max(0, ...props.series.flatMap((s) => s.values))))
const plotWidth = computed(() => Math.max(0, width.value - PAD.left - PAD.right))
const plotHeight = HEIGHT - PAD.top - PAD.bottom
const x = (i: number) => PAD.left + (count.value > 1 ? (i / (count.value - 1)) * plotWidth.value : 0)
const y = (value: number) => PAD.top + plotHeight - (value / max.value) * plotHeight

const ticks = computed(() => [0, 1, 2, 3, 4].map((step) => (max.value / 4) * step))
const xTicks = computed(() => {
  const every = plotWidth.value < 360 ? 10 : 5
  return labels.value.map((label, i) => ({ label, i })).filter(({ i }) => (count.value - 1 - i) % every === 0)
})
const paths = computed(() =>
  props.series.map((s) => {
    const points: Point[] = s.values.map((value, i) => [x(i), y(value)])
    const line = smoothPath(points)
    return { ...s, line, area: `${line}L${x(count.value - 1)},${y(0)}L${x(0)},${y(0)}Z` }
  }),
)

function track(event: PointerEvent) {
  if (!box.value || count.value < 2) return
  const left = event.clientX - box.value.getBoundingClientRect().left - PAD.left
  hover.value = Math.min(count.value - 1, Math.max(0, Math.round((left / plotWidth.value) * (count.value - 1))))
}
const tooltipLeft = computed(() => (hover.value === null ? 0 : x(hover.value)))
const tooltipFlip = computed(() => tooltipLeft.value > width.value - 170)
</script>

<template>
  <div
    ref="box"
    class="relative select-none"
    :style="{ height: `${HEIGHT}px` }"
    @pointermove="track"
    @pointerleave="hover = null"
  >
    <svg
      v-if="width"
      :width="width"
      :height="HEIGHT"
      class="block overflow-visible"
      role="img"
      :aria-label="series.map((s) => `${s.label}: ${s.values.reduce((a, b) => a + b, 0)} in ${count} days`).join(', ')"
    >
      <defs>
        <linearGradient
          v-for="s in series"
          :id="`${id}-${s.key}`"
          :key="s.key"
          :class="s.color"
          x1="0"
          x2="0"
          y1="0"
          y2="1"
        >
          <stop offset="0%" stop-color="currentColor" stop-opacity="0.22" />
          <stop offset="100%" stop-color="currentColor" stop-opacity="0" />
        </linearGradient>
      </defs>
      <g class="text-gray-400 dark:text-gray-500">
        <g v-for="tick in ticks" :key="tick">
          <line
            :x1="PAD.left"
            :x2="width - PAD.right"
            :y1="y(tick)"
            :y2="y(tick)"
            class="stroke-gray-100 dark:stroke-gray-800"
            :stroke-dasharray="tick ? '3 4' : undefined"
          />
          <text
            :x="PAD.left - 8"
            :y="y(tick)"
            dy="0.32em"
            text-anchor="end"
            class="fill-current text-[11px] tabular-nums"
          >
            {{ tick }}
          </text>
        </g>
        <text
          v-for="tick in xTicks"
          :key="tick.i"
          :x="x(tick.i)"
          :y="HEIGHT - 6"
          :text-anchor="tick.i === count - 1 ? 'end' : 'middle'"
          class="fill-current text-[11px]"
        >
          {{ tick.label }}
        </text>
      </g>
      <g v-for="s in paths" :key="s.key" :class="s.color">
        <path :d="s.area" :fill="`url(#${id}-${s.key})`" />
        <path
          :d="s.line"
          fill="none"
          stroke="currentColor"
          stroke-width="2"
          stroke-linejoin="round"
          stroke-linecap="round"
        />
      </g>
      <g v-if="hover !== null">
        <line :x1="x(hover)" :x2="x(hover)" :y1="PAD.top" :y2="y(0)" class="stroke-gray-300 dark:stroke-gray-600" />
        <circle
          v-for="s in series"
          :key="s.key"
          :cx="x(hover)"
          :cy="y(s.values[hover])"
          r="4"
          :class="[s.color, 'stroke-white dark:stroke-gray-900']"
          fill="currentColor"
          stroke-width="2"
        />
      </g>
    </svg>
    <div
      v-if="hover !== null"
      class="pointer-events-none absolute top-2 z-10 min-w-36 rounded-lg border border-gray-200 bg-white/95 px-3 py-2 text-xs shadow-lg backdrop-blur dark:border-gray-700 dark:bg-gray-900/95"
      :style="{
        left: `${tooltipLeft + (tooltipFlip ? -12 : 12)}px`,
        transform: tooltipFlip ? 'translateX(-100%)' : undefined,
      }"
    >
      <p class="mb-1 font-medium text-gray-900 dark:text-white">{{ longLabels[hover] }}</p>
      <p v-for="s in series" :key="s.key" class="flex items-center gap-2 text-gray-600 dark:text-gray-300">
        <span :class="['size-2 rounded-full', s.dot]" />{{ s.label }}
        <span class="ms-auto font-medium text-gray-900 tabular-nums dark:text-white">{{ s.values[hover] }}</span>
      </p>
    </div>
  </div>
</template>
