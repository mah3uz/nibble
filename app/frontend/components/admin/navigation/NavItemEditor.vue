<script setup lang="ts">
import { computed, reactive, watch } from 'vue'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select'
import { Sheet, SheetContent, SheetFooter, SheetHeader, SheetTitle } from '@/components/ui/sheet'
import LinkUrlInput from '@/nibble-admin/components/LinkUrlInput.vue'
import EntryPicker from './EntryPicker.vue'
import type { NavEntry, NavTreeItem } from './types'

const props = defineProps<{ open: boolean; item: NavTreeItem | null; entries: NavEntry[] }>()
const emit = defineEmits<{ save: [NavTreeItem]; 'update:open': [boolean] }>()

const TITLE_MAX_LENGTH = 60
const URL_FORMAT = /^(https:\/\/\S+|\/\S*)$/

const form = reactive({
  title: '',
  linkType: 'url',
  url: '',
  entryId: null as number | null,
})

const groupKey = (entry: NavEntry) => `${entry.type}:${entry.group}`
const groups = computed(() => [
  ...new Map(
    props.entries.map((entry) => [groupKey(entry), { value: groupKey(entry), label: entry.group_title }]),
  ).values(),
])

watch(
  () => [props.open, props.item] as const,
  ([open, item]) => {
    if (!open) return
    form.title = item?.title ?? ''
    const link = item?.link
    const linked =
      link && link.type !== 'url' ? props.entries.find((e) => e.type === link.type && e.id === link.id) : null
    form.linkType = linked ? groupKey(linked) : 'url'
    form.url = link?.type === 'url' ? link.url : ''
    form.entryId = linked?.id ?? null
  },
  { immediate: true },
)

const pickerEntries = computed(() => props.entries.filter((entry) => groupKey(entry) === form.linkType))
const pickerLabel = computed(() => groups.value.find((group) => group.value === form.linkType)?.label ?? '')
const valid = computed(
  () =>
    form.title.trim().length > 0 &&
    form.title.length <= TITLE_MAX_LENGTH &&
    (form.linkType === 'url' ? URL_FORMAT.test(form.url) : form.entryId !== null),
)

function save() {
  if (!valid.value) return
  const link: NavTreeItem['link'] =
    form.linkType === 'url'
      ? { type: 'url', url: form.url }
      : { type: form.linkType.split(':')[0] as 'entry' | 'term', id: form.entryId! }
  emit('save', {
    id: props.item?.id ?? crypto.randomUUID(),
    title: form.title.trim(),
    link,
    children: props.item?.children ?? [],
  })
}
</script>

<template>
  <Sheet :open="open" @update:open="(value) => emit('update:open', value)">
    <SheetContent size="narrow" class="gap-0">
      <SheetHeader>
        <SheetTitle>{{ item ? 'Edit link' : 'Add link' }}</SheetTitle>
      </SheetHeader>
      <form class="flex-1 space-y-4 overflow-y-auto p-6" @submit.prevent="save">
        <div class="space-y-2">
          <Label for="nav-item-title">Title</Label>
          <Input id="nav-item-title" v-model="form.title" :maxlength="TITLE_MAX_LENGTH" required />
        </div>
        <div class="space-y-2">
          <Label for="nav-item-link-type">Link type</Label>
          <Select v-model="form.linkType" @update:model-value="form.entryId = null">
            <SelectTrigger id="nav-item-link-type" class="w-full"><SelectValue /></SelectTrigger>
            <SelectContent>
              <SelectItem value="url">URL</SelectItem>
              <SelectItem v-for="group in groups" :key="group.value" :value="group.value">{{ group.label }}</SelectItem>
            </SelectContent>
          </Select>
        </div>
        <div v-if="form.linkType === 'url'" class="space-y-2">
          <Label for="nav-item-url">URL</Label>
          <LinkUrlInput id="nav-item-url" v-model="form.url" @submit="save" />
        </div>
        <div v-else class="space-y-2">
          <Label>{{ pickerLabel }}</Label>
          <EntryPicker v-model="form.entryId" :entries="pickerEntries" />
        </div>
      </form>
      <SheetFooter>
        <Button type="button" :disabled="!valid" @click="save">Save</Button>
      </SheetFooter>
    </SheetContent>
  </Sheet>
</template>
