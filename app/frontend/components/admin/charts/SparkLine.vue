<script setup lang="ts">
import { computed, useId } from 'vue'
import { smoothPath, type Point } from '@/lib/chart'

const props = defineProps<{ values: number[] }>()

const WIDTH = 200
const HEIGHT = 48
const id = useId()

const points = computed<Point[]>(() => {
  const max = Math.max(1, ...props.values)
  const step = WIDTH / Math.max(1, props.values.length - 1)
  return props.values.map((value, i) => [i * step, HEIGHT - 2 - (value / max) * (HEIGHT - 6)])
})
const line = computed(() => smoothPath(points.value))
const area = computed(() => `${line.value}L${WIDTH},${HEIGHT}L0,${HEIGHT}Z`)
</script>

<template>
  <svg :viewBox="`0 0 ${WIDTH} ${HEIGHT}`" preserveAspectRatio="none" class="block h-12 w-full" aria-hidden="true">
    <defs>
      <linearGradient :id="`${id}-fill`" x1="0" x2="0" y1="0" y2="1">
        <stop offset="0%" stop-color="currentColor" stop-opacity="0.28" />
        <stop offset="100%" stop-color="currentColor" stop-opacity="0" />
      </linearGradient>
    </defs>
    <path :d="area" :fill="`url(#${id}-fill)`" />
    <path
      :d="line"
      fill="none"
      stroke="currentColor"
      stroke-width="1.75"
      vector-effect="non-scaling-stroke"
      stroke-linejoin="round"
    />
  </svg>
</template>
