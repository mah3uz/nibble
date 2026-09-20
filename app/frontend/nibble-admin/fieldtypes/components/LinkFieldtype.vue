<script setup lang="ts">
import { computed, ref, watch } from 'vue'
import { Input } from '@/components/ui/input'
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select'
import type { ItemSummary } from '../../lib/relationships'
import { fieldtypeEmits, fieldtypeProps, useFieldtype } from '../useFieldtype'
import RecordSearch from './RecordSearch.vue'

const props = defineProps(fieldtypeProps)
const emit = defineEmits(fieldtypeEmits)
const { update, updateMeta, updateDebounced, isReadOnly, expose } = useFieldtype(emit, props)
defineExpose(expose)

const types = computed(() => (props.meta.types as Record<string, { title: string }>) ?? {})
const option = ref<string | null>((props.meta.initial_option as string) ?? null)
const url = ref((props.meta.initial_url as string) ?? '')
const item = computed(() => props.meta.item as ItemSummary | null)
const NONE = '__none__'

watch(
  () => props.value,
  (value) => {
    if (typeof value !== 'string' || value === '') return
    const [type] = value.split('::')
    option.value = value.includes('::') && types.value[type!] ? type! : 'url'
    if (option.value === 'url') url.value = value
  },
)

function choose(next: string) {
  option.value = next === NONE ? null : next
  update(option.value === 'url' && url.value ? url.value : null)
}

function pick(picked: ItemSummary) {
  updateMeta({ ...props.meta, item: picked })
  update(`${option.value}::${picked.id}`)
}

const scope = computed(() =>
  option.value === 'entry'
    ? { collections: props.config.collections ?? [] }
    : { taxonomies: props.config.taxonomies ?? [] },
)
</script>

<template>
  <div :id="id" class="flex flex-col gap-2 sm:flex-row">
    <Select :model-value="option ?? NONE" :disabled="isReadOnly" @update:model-value="(next) => choose(String(next))">
      <SelectTrigger class="sm:w-40" aria-label="Link type"><SelectValue /></SelectTrigger>
      <SelectContent>
        <SelectItem :value="NONE">None</SelectItem>
        <SelectItem value="url">URL</SelectItem>
        <SelectItem v-for="(type, handle) in types" :key="handle" :value="handle">{{ type.title }}</SelectItem>
      </SelectContent>
    </Select>
    <Input
      v-if="option === 'url'"
      :model-value="url"
      :disabled="isReadOnly"
      placeholder="https:// or /path"
      class="flex-1"
      @update:model-value="(text) => updateDebounced((url = String(text)))"
    />
    <div v-else-if="option" class="flex flex-1 flex-col gap-1">
      <RecordSearch
        :type="option"
        :scope="scope"
        :selected-ids="item ? [item.id] : []"
        :label="item?.title ?? `Choose ${types[option]?.title.toLowerCase() ?? option}…`"
        :disabled="isReadOnly"
        @pick="pick"
      />
      <span v-if="item?.url" class="truncate text-xs text-muted-foreground">{{ item.url }}</span>
    </div>
  </div>
</template>
