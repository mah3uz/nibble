<script setup lang="ts">
import { useSortable } from '@vueuse/integrations/useSortable'
import { router } from '@inertiajs/vue3'
import { GripVertical, Plus, Trash2 } from '@lucide/vue'
import { computed, ref, useTemplateRef, watch } from 'vue'
import { Button } from '@/components/ui/button'
import { Command, CommandEmpty, CommandGroup, CommandItem, CommandList } from '@/components/ui/command'
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from '@/components/ui/dialog'
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select'
import { Popover, PopoverContent, PopoverTrigger } from '@/components/ui/popover'
import { setPreferenceNow } from '@/lib/preferences'
import type { AvailableWidget, WidgetLayoutItem } from './types'

const props = defineProps<{ open: boolean; layout: WidgetLayoutItem[]; available: AvailableWidget[] }>()
const emit = defineEmits<{ 'update:open': [boolean] }>()

const WIDTH_LABEL: Record<number, string> = { 33: '1/3', 50: '1/2', 66: '2/3', 100: 'Full' }
// Reka's Select rejects an empty value.
const AUTO_HEIGHT = 'auto'
const HEIGHT_OPTIONS = [AUTO_HEIGHT, '12rem', '16rem', '20rem', '24rem', '32rem', '40rem']

const rows = ref<WidgetLayoutItem[]>([])
watch(
  () => props.open,
  (open) => {
    if (open) rows.value = props.layout.map((widget) => ({ ...widget }))
  },
)

const labelFor = (type: string) => props.available.find((widget) => widget.type === type)?.label ?? type
const addable = computed(() => props.available.filter((widget) => !rows.value.some((row) => row.type === widget.type)))

const addOpen = ref(false)
function add(type: string) {
  rows.value = [...rows.value, { type, width: 50 }]
  addOpen.value = false
}
function remove(index: number) {
  rows.value = rows.value.filter((_, i) => i !== index)
}

const saving = ref(false)
async function save() {
  saving.value = true
  await setPreferenceNow('dashboard.widgets', rows.value)
  router.reload({
    onFinish: () => {
      saving.value = false
      emit('update:open', false)
    },
  })
}

// DialogContent mounts its slot after opening, and its transform would misplace the drag clone.
const listRef = useTemplateRef<HTMLElement>('list')
useSortable(listRef, rows, {
  handle: '.drag-handle',
  watchElement: true,
  forceFallback: true,
  fallbackOnBody: true,
  dragClass: 'sortable-drag-clone',
  ghostClass: 'sortable-ghost-placeholder',
})
</script>

<template>
  <Dialog :open="open" @update:open="(value) => emit('update:open', value)">
    <DialogContent class="sm:max-w-lg">
      <DialogHeader>
        <DialogTitle>Customize dashboard</DialogTitle>
        <DialogDescription>Choose which widgets show, their order and width.</DialogDescription>
      </DialogHeader>

      <div ref="list" class="space-y-2">
        <div
          v-for="(row, index) in rows"
          :key="row.type"
          class="flex flex-wrap items-center gap-2 rounded-md border p-2"
        >
          <GripVertical class="drag-handle size-4 shrink-0 cursor-grab text-muted-foreground" />
          <span class="min-w-24 flex-1 truncate text-sm">{{ labelFor(row.type) }}</span>
          <Select
            :model-value="String(row.width)"
            @update:model-value="(v) => (row.width = Number(v) as 33 | 50 | 66 | 100)"
          >
            <SelectTrigger size="sm" class="w-20" aria-label="Width"><SelectValue /></SelectTrigger>
            <SelectContent>
              <SelectItem v-for="width in [33, 50, 66, 100]" :key="width" :value="String(width)">{{
                WIDTH_LABEL[width]
              }}</SelectItem>
            </SelectContent>
          </Select>
          <Select
            :model-value="row.height ?? AUTO_HEIGHT"
            @update:model-value="(v) => (row.height = v === AUTO_HEIGHT ? null : String(v))"
          >
            <SelectTrigger size="sm" class="w-24" aria-label="Height"><SelectValue /></SelectTrigger>
            <SelectContent>
              <SelectItem v-for="height in HEIGHT_OPTIONS" :key="height" :value="height">{{
                height === AUTO_HEIGHT ? 'Auto' : height
              }}</SelectItem>
            </SelectContent>
          </Select>
          <Button type="button" size="icon-sm" variant="ghost" aria-label="Remove" @click="remove(index)"
            ><Trash2
          /></Button>
        </div>
        <p v-if="!rows.length" class="text-sm text-muted-foreground">No widgets — add one below.</p>
      </div>

      <Popover v-if="addable.length" v-model:open="addOpen">
        <PopoverTrigger as-child>
          <Button type="button" variant="outline" size="sm" class="w-full"><Plus /> Add a widget</Button>
        </PopoverTrigger>
        <PopoverContent class="w-72 p-0">
          <Command>
            <CommandList>
              <CommandEmpty>No more widgets to add.</CommandEmpty>
              <CommandGroup>
                <CommandItem
                  v-for="widget in addable"
                  :key="widget.type"
                  :value="widget.label"
                  @select="add(widget.type)"
                >
                  {{ widget.label }}
                </CommandItem>
              </CommandGroup>
            </CommandList>
          </Command>
        </PopoverContent>
      </Popover>

      <DialogFooter>
        <Button type="button" variant="ghost" :disabled="saving" @click="emit('update:open', false)">Cancel</Button>
        <Button type="button" :disabled="saving" @click="save">Save</Button>
      </DialogFooter>
    </DialogContent>
  </Dialog>
</template>
