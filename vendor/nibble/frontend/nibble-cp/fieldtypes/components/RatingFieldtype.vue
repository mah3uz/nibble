<script setup lang="ts">
import { computed, ref } from 'vue'
import { Star } from '@lucide/vue'
import { ratingAfterKey } from '../rating'
import { fieldtypeEmits, fieldtypeProps, useFieldtype } from '../useFieldtype'

const props = defineProps(fieldtypeProps)
const emit = defineEmits(fieldtypeEmits)
const { update, isReadOnly, expose } = useFieldtype(emit, props)
defineExpose(expose)

const max = computed(() => Math.min(10, Math.max(2, (props.config.max as number | undefined) ?? 5)))
const current = computed(() => (typeof props.value === 'number' ? props.value : null))
const stars = ref<HTMLElement[]>([])

function choose(n: number | null) {
  if (!isReadOnly.value) update(n)
}

function onKey(event: KeyboardEvent, n: number) {
  const next = ratingAfterKey(event.key, n, max.value)
  if (next === undefined) return
  event.preventDefault()
  choose(next)
  if (next !== null) stars.value[next - 1]?.focus()
}
</script>

<template>
  <div :id="id" role="radiogroup" class="flex items-center gap-0.5" :aria-readonly="isReadOnly || undefined">
    <button
      v-for="n in max"
      :key="n"
      :ref="(el) => (stars[n - 1] = el as HTMLElement)"
      type="button"
      role="radio"
      :aria-checked="current === n"
      :aria-label="`${n} of ${max}`"
      :tabindex="current === n || (current === null && n === 1) ? 0 : -1"
      :disabled="isReadOnly"
      class="rounded-sm p-0.5 outline-none focus-visible:focus-outline disabled:opacity-60"
      :class="current !== null && n <= current ? 'text-primary' : 'text-gray-300 dark:text-gray-600'"
      @click="choose(current === n ? null : n)"
      @keydown="onKey($event, n)"
    >
      <Star class="size-6" :fill="current !== null && n <= current ? 'currentColor' : 'none'" aria-hidden="true" />
    </button>
  </div>
</template>
