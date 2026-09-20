<script setup lang="ts">
import { useSortable } from '@vueuse/integrations/useSortable'
import { GripVertical, SlidersVertical } from '@lucide/vue'
import { computed, ref, useTemplateRef } from 'vue'
import { Button } from '@/components/ui/button'
import { Checkbox } from '@/components/ui/checkbox'
import { Dialog, DialogContent, DialogFooter, DialogHeader, DialogTitle } from '@/components/ui/dialog'
import type { ListingColumn } from './types'

const props = defineProps<{ columns: ListingColumn[] }>()
const emit = defineEmits<{ change: [handles: string[]] }>()

const open = ref(false)
const displayed = ref<ListingColumn[]>([])

const available = computed(() =>
  props.columns.filter((column) => !displayed.value.some((shown) => shown.handle === column.handle)),
)

function start() {
  displayed.value = props.columns.filter((column) => column.visible)
  open.value = true
}

const show = (column: ListingColumn) => (displayed.value = [...displayed.value, column])
const hide = (column: ListingColumn) =>
  (displayed.value = displayed.value.filter((shown) => shown.handle !== column.handle))

function reset() {
  const order = props.columns.map((column) => column.handle)
  displayed.value = props.columns
    .filter((column) => column.default)
    .sort((a, b) => order.indexOf(a.handle) - order.indexOf(b.handle))
}

function save() {
  emit(
    'change',
    displayed.value.map((column) => column.handle),
  )
  open.value = false
}

// DialogContent mounts its slot after opening, and its transform would misplace the drag clone.
const listRef = useTemplateRef<HTMLElement>('list')
useSortable(listRef, displayed, {
  handle: '.drag-handle',
  watchElement: true,
  forceFallback: true,
  fallbackOnBody: true,
  dragClass: 'sortable-drag-clone',
  ghostClass: 'sortable-ghost-placeholder',
})
</script>

<template>
  <Button variant="outline" size="icon" aria-label="Customize columns" @click="start"><SlidersVertical /></Button>
  <Dialog v-model:open="open">
    <DialogContent class="gap-0 p-0 sm:max-w-2xl">
      <div class="rounded-xl bg-white p-4 dark:bg-gray-850">
        <DialogHeader class="mb-4">
          <DialogTitle>Customize Columns</DialogTitle>
        </DialogHeader>
        <div
          class="grid min-h-72 grid-cols-2 overflow-hidden rounded-lg border border-gray-200 text-sm dark:border-gray-700"
        >
          <section class="flex flex-col border-e border-gray-200 dark:border-gray-700">
            <h3
              class="border-b border-gray-200 bg-gray-50 px-4 py-2.5 font-medium text-gray-900 dark:border-gray-700 dark:bg-gray-900 dark:text-white"
            >
              Available Columns
            </h3>
            <ul class="flex-1 space-y-1.5 overflow-y-auto p-4">
              <li v-for="column in available" :key="column.handle">
                <label class="flex cursor-pointer items-center gap-2.5 text-gray-800 dark:text-gray-200">
                  <Checkbox :model-value="false" @update:model-value="show(column)" />
                  {{ column.label }}
                </label>
              </li>
              <li v-if="!available.length" class="text-gray-500">Every column is displayed.</li>
            </ul>
          </section>
          <section class="flex flex-col">
            <h3
              class="border-b border-gray-200 bg-gray-50 px-4 py-2.5 font-medium text-gray-900 dark:border-gray-700 dark:bg-gray-900 dark:text-white"
            >
              Displayed Columns
            </h3>
            <ul ref="list" class="flex-1 space-y-2 overflow-y-auto p-3">
              <li
                v-for="column in displayed"
                :key="column.handle"
                class="flex items-center gap-2.5 rounded-lg bg-gray-100 px-2.5 py-2 text-gray-800 dark:bg-gray-800 dark:text-gray-200"
              >
                <GripVertical class="drag-handle size-4 shrink-0 cursor-grab text-gray-400" aria-hidden="true" />
                <Checkbox
                  :model-value="true"
                  :aria-label="`Hide ${column.label}`"
                  :disabled="displayed.length === 1"
                  @update:model-value="hide(column)"
                />
                {{ column.label }}
              </li>
            </ul>
          </section>
        </div>
      </div>
      <DialogFooter class="px-4 py-3">
        <Button variant="ghost" @click="open = false">Cancel</Button>
        <Button variant="outline" @click="reset">Reset</Button>
        <Button @click="save">Save</Button>
      </DialogFooter>
    </DialogContent>
  </Dialog>
</template>
