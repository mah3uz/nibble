<script setup lang="ts">
import { computed } from 'vue'
import CpIcon from '@/components/cp/icons/CpIcon.vue'
import { Button } from '@/components/ui/button'
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select'

const props = defineProps<{
  page: number
  perPage: number
  total: number
  pages: number
  perPageOptions: number[]
}>()
const emit = defineEmits<{ page: [number]; 'per-page': [number] }>()

const EACH_SIDE = 3

const range = (from: number, to: number) => Array.from({ length: to - from + 1 }, (_, i) => from + i)

const links = computed<(number | null)[]>(() => {
  const last = props.pages
  if (last < 12) return range(1, last)
  if (props.page <= EACH_SIDE * 2) return [...range(1, 8), null, last - 1, last]
  if (props.page > last - EACH_SIDE * 2) return [1, 2, null, ...range(last - 8, last)]
  return [1, 2, null, ...range(props.page - EACH_SIDE, props.page + EACH_SIDE), null, last - 1, last]
})

const from = computed(() => (props.total ? (props.page - 1) * props.perPage + 1 : 0))
const to = computed(() => Math.min(props.page * props.perPage, props.total))
const perPageUseful = computed(() => props.total > Math.min(...props.perPageOptions))
</script>

<template>
  <div class="flex items-center gap-2 px-4.5 pt-2.5 pb-1.5 antialiased md:pt-3">
    <div class="flex flex-1 items-center">
      <span v-if="total" class="text-sm text-gray-600 tabular-nums dark:text-gray-500"
        >{{ from.toLocaleString() }}–{{ to.toLocaleString() }} of {{ total.toLocaleString() }}</span
      >
    </div>
    <nav v-if="pages > 1" aria-label="Pagination" class="flex items-center gap-1">
      <Button
        variant="ghost"
        size="icon-sm"
        class="rounded-full"
        aria-label="Previous page"
        :disabled="page <= 1"
        @click="emit('page', page - 1)"
        ><CpIcon name="chevron-left"
      /></Button>
      <template v-for="(link, index) in links" :key="index">
        <span v-if="link === null" class="px-1 text-sm text-gray-500" aria-hidden="true">…</span>
        <Button
          v-else
          :variant="link === page ? 'secondary' : 'ghost'"
          size="sm"
          class="min-w-8 rounded-full px-2 tabular-nums"
          :aria-current="link === page ? 'page' : undefined"
          @click="link !== page && emit('page', link)"
          >{{ link }}</Button
        >
      </template>
      <Button
        variant="ghost"
        size="icon-sm"
        class="rounded-full"
        aria-label="Next page"
        :disabled="page >= pages"
        @click="emit('page', page + 1)"
        ><CpIcon name="chevron-right"
      /></Button>
    </nav>
    <div v-if="perPageUseful" class="flex flex-1 items-center justify-end">
      <span class="me-3 text-sm text-gray-600 dark:text-gray-500">Per Page</span>
      <Select :model-value="String(perPage)" @update:model-value="(v) => emit('per-page', Number(v))">
        <SelectTrigger size="sm" aria-label="Per page" class="w-auto"><SelectValue /></SelectTrigger>
        <SelectContent>
          <SelectItem v-for="option in perPageOptions" :key="option" :value="String(option)">{{ option }}</SelectItem>
        </SelectContent>
      </Select>
    </div>
    <div v-else class="flex-1" />
  </div>
</template>
