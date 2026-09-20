<script setup lang="ts">
import { GripVertical, Plus, X } from '@lucide/vue'
import { useSortable } from '@vueuse/integrations/useSortable'
import { computed, nextTick, ref, useTemplateRef, watch } from 'vue'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { fieldtypeEmits, fieldtypeProps, useFieldtype } from '../useFieldtype'

const props = defineProps(fieldtypeProps)
const emit = defineEmits(fieldtypeEmits)
const { update, isReadOnly, expose } = useFieldtype(emit, props)
defineExpose(expose)

const items = ref<string[]>([...((props.value as string[] | null) ?? []).map(String)])
watch(
  () => props.value,
  (value) => (items.value = [...((value as string[] | null) ?? []).map(String)]),
)
const listRef = useTemplateRef<HTMLElement>('list')
useSortable(listRef, items, {
  handle: '.drag-handle',
  forceFallback: true,
  dragClass: 'sortable-drag-clone',
  ghostClass: 'sortable-ghost-placeholder',
  onUpdate: () => nextTick(() => update([...items.value])),
})

const addLabel = computed(() => (props.config.add_row as string) || 'Add item')

function set(index: number, text: string) {
  items.value[index] = text
  update([...items.value])
}

async function add(at = items.value.length) {
  items.value.splice(at, 0, '')
  update([...items.value])
  await nextTick()
  listRef.value?.querySelectorAll('input')[at]?.focus()
}

function remove(index: number) {
  items.value.splice(index, 1)
  update([...items.value])
}
</script>

<template>
  <div :id="id" class="space-y-2">
    <div ref="list" class="space-y-2">
      <div v-for="(item, index) in items" :key="index" class="flex items-center gap-2">
        <GripVertical v-if="!isReadOnly" class="drag-handle size-4 shrink-0 cursor-grab text-gray-400" />
        <Input
          :model-value="item"
          :disabled="isReadOnly"
          :aria-label="`Item ${index + 1}`"
          @update:model-value="(text) => set(index, String(text))"
          @keydown.enter.prevent="add(index + 1)"
        />
        <Button
          v-if="!isReadOnly"
          type="button"
          variant="ghost"
          size="icon-sm"
          :aria-label="`Remove item ${index + 1}`"
          @click="remove(index)"
          ><X
        /></Button>
      </div>
    </div>
    <Button v-if="!isReadOnly" type="button" variant="outline" size="sm" @click="add()"><Plus />{{ addLabel }}</Button>
  </div>
</template>
