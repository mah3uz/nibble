<script setup lang="ts">
import { Check, ChevronsUpDown, X } from '@lucide/vue'
import { computed, ref } from 'vue'
import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import { Command, CommandEmpty, CommandGroup, CommandInput, CommandItem, CommandList } from '@/components/ui/command'
import { Popover, PopoverContent, PopoverTrigger } from '@/components/ui/popover'
import { normalizeOptions, optionKey } from '../options'
import { fieldtypeEmits, fieldtypeProps, useFieldtype } from '../useFieldtype'

const props = defineProps(fieldtypeProps)
const emit = defineEmits(fieldtypeEmits)
const { update, isReadOnly, expose } = useFieldtype(emit, props)
defineExpose(expose)

const open = ref(false)
const search = ref('')
const multiple = computed(() => props.config.multiple === true)
const options = computed(() => normalizeOptions(props.meta, props.config))
const selected = computed<unknown[]>(() =>
  multiple.value ? ((props.value as unknown[] | null) ?? []) : props.value == null ? [] : [props.value],
)
const labelFor = (value: unknown) =>
  options.value.find((option) => optionKey(option.value) === optionKey(value))?.label ?? String(value)
const isSelected = (value: unknown) => selected.value.some((item) => optionKey(item) === optionKey(value))
const maxReached = computed(() => {
  const max = Number(props.config.max_items) || 0
  return multiple.value && max > 0 && selected.value.length >= max
})
const canAdd = computed(
  () =>
    props.config.taggable === true &&
    search.value.trim() !== '' &&
    !options.value.some((option) => option.label === search.value.trim()),
)

function choose(value: unknown) {
  if (!multiple.value) {
    update(isSelected(value) && props.config.clearable ? null : value)
    open.value = false
    return
  }
  if (isSelected(value)) update(selected.value.filter((item) => optionKey(item) !== optionKey(value)))
  else if (!maxReached.value) update([...selected.value, value])
  search.value = ''
}

function remove(value: unknown) {
  update(multiple.value ? selected.value.filter((item) => optionKey(item) !== optionKey(value)) : null)
}
</script>

<template>
  <Popover :open="open && !isReadOnly" @update:open="(value) => (open = value)">
    <PopoverTrigger as-child>
      <Button
        :id="id"
        type="button"
        variant="outline"
        role="combobox"
        :aria-expanded="open && !isReadOnly"
        :aria-readonly="isReadOnly || undefined"
        class="h-auto min-h-10 w-full justify-between font-normal"
        :class="{ 'cursor-default border-dashed shadow-none': isReadOnly }"
      >
        <span class="flex flex-wrap items-center gap-1 text-start">
          <template v-if="multiple">
            <Badge v-for="item in selected" :key="optionKey(item)" variant="secondary" class="gap-1">
              {{ labelFor(item) }}
              <X v-if="!isReadOnly" class="size-3" aria-label="Remove" @click.stop="remove(item)" />
            </Badge>
          </template>
          <span v-else-if="selected.length">{{ labelFor(selected[0]) }}</span>
          <span v-if="!selected.length" class="text-muted-foreground">{{ config.placeholder || 'Choose…' }}</span>
        </span>
        <span class="flex items-center gap-1">
          <X
            v-if="!multiple && config.clearable && selected.length && !isReadOnly"
            class="size-4 opacity-60"
            aria-label="Clear"
            @click.stop="update(null)"
          />
          <ChevronsUpDown class="size-4 opacity-50" />
        </span>
      </Button>
    </PopoverTrigger>
    <PopoverContent class="w-(--reka-popover-trigger-width) p-0" align="start">
      <Command v-model:search-term="search">
        <CommandInput v-if="config.searchable !== false || config.taggable" placeholder="Search…" />
        <CommandList>
          <CommandEmpty v-if="!canAdd">No options.</CommandEmpty>
          <CommandGroup>
            <CommandItem
              v-for="option in options"
              :key="optionKey(option.value)"
              :value="option.label"
              :disabled="maxReached && !isSelected(option.value)"
              @select="choose(option.value)"
            >
              <Check class="size-4" :class="isSelected(option.value) ? 'opacity-100' : 'opacity-0'" />
              {{ option.label }}
            </CommandItem>
            <CommandItem v-if="canAdd" :value="search" @select="choose(search.trim())"
              >Add “{{ search.trim() }}”</CommandItem
            >
          </CommandGroup>
        </CommandList>
      </Command>
    </PopoverContent>
  </Popover>
</template>
