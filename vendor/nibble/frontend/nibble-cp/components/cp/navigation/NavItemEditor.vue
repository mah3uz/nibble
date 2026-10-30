<script setup lang="ts">
import { AlertCircle } from '@lucide/vue'
import { computed, reactive, ref, watch } from 'vue'
import type { AssetRow } from '@/components/cp/assets/api'
import AssetSelector from '@/components/cp/assets/AssetSelector.vue'
import { Alert, AlertDescription } from '@/components/ui/alert'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import {
  Select,
  SelectContent,
  SelectGroup,
  SelectItem,
  SelectLabel,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select'
import { Sheet, SheetContent, SheetFooter, SheetHeader, SheetTitle } from '@/components/ui/sheet'
import { Switch } from '@/components/ui/switch'
import LinkUrlInput from '@nibble-cp/components/LinkUrlInput.vue'
import PublishContainer from '@nibble-cp/publish/PublishContainer.vue'
import PublishFields from '@nibble-cp/publish/PublishFields.vue'
import { useNavEditor } from './context'
import EntryPicker from './EntryPicker.vue'
import type { NavEntry, NavKind, NavLink, NavTreeItem } from './types'

const props = defineProps<{ open: boolean; item: NavTreeItem | null; kind: NavKind }>()
const emit = defineEmits<{ save: [NavTreeItem]; 'update:open': [boolean] }>()
const { menu, entries, assets, errors } = useNavEditor()

const TITLE_MAX_LENGTH = 60
const URL_FORMAT = /^(https:\/\/\S+|\/\S*)$/
const NO_BLUEPRINT = { handle: 'item', title: '', tabs: [] }

const form = reactive({
  title: '',
  linkType: 'url',
  url: '',
  entryId: null as number | null,
  globalRef: '',
  assetId: null as number | null,
  newTab: false,
  hidden: false,
  fields: {} as Record<string, unknown>,
  fieldMeta: {} as Record<string, unknown>,
})
const pickingFile = ref(false)

const kind = computed(() => props.item?.kind ?? props.kind)
const noun = computed(() => (kind.value === 'heading' ? 'heading' : 'link'))
const globals = computed(() => menu.globals ?? [])
const itemFields = computed(() => menu.item_fields ?? [])
const itemErrors = computed(() => (props.item ? errors.value[props.item.id] : undefined))
const itemMessages = computed(() => {
  const onFields = Object.values(itemErrors.value?.fields ?? {}).flat()
  return (itemErrors.value?.messages ?? []).filter((message) => !onFields.includes(message))
})

const groupKey = (entry: NavEntry) => `${entry.type}:${entry.group}`
const groups = computed(() => [
  ...new Map(entries.map((entry) => [groupKey(entry), { value: groupKey(entry), label: entry.group_title }])).values(),
])

watch(
  () => [props.open, props.item] as const,
  ([open, item]) => {
    if (!open) return
    form.title = item?.title ?? ''
    const link = item?.link
    const linked =
      link && (link.type === 'entry' || link.type === 'term')
        ? entries.find((e) => e.type === link.type && e.id === link.id)
        : null
    form.linkType = linked ? groupKey(linked) : link?.type === 'global' || link?.type === 'asset' ? link.type : 'url'
    form.url = link?.type === 'url' ? link.url : ''
    form.entryId = linked?.id ?? null
    form.globalRef = link?.type === 'global' ? link.ref : ''
    form.assetId = link?.type === 'asset' ? link.id : null
    form.newTab = item?.new_tab ?? false
    form.hidden = item?.hidden ?? false
    form.fields = { ...(item?.fields ?? {}) }
    form.fieldMeta = { ...(item?.field_meta ?? {}) }
  },
  { immediate: true },
)

const pickerEntries = computed(() => entries.filter((entry) => groupKey(entry) === form.linkType))
const pickerLabel = computed(() => groups.value.find((group) => group.value === form.linkType)?.label ?? '')
const pickedGlobal = computed(() =>
  globals.value
    .flatMap((global) => global.fields.map((field) => ({ ref: `global:${global.handle}.${field.handle}`, field })))
    .find((choice) => choice.ref === form.globalRef),
)
const pickedFile = computed(() => (form.assetId === null ? null : assets.value[String(form.assetId)]))

const linkValid = computed(() => {
  if (kind.value === 'heading') return true
  if (form.linkType === 'url') return URL_FORMAT.test(form.url)
  if (form.linkType === 'global') return !!pickedGlobal.value
  if (form.linkType === 'asset') return form.assetId !== null
  return form.entryId !== null
})
const valid = computed(() => form.title.trim().length > 0 && form.title.length <= TITLE_MAX_LENGTH && linkValid.value)

function pickFile(rows: AssetRow[]) {
  const row = rows[0]
  if (!row) return
  assets.value = {
    ...assets.value,
    [String(row.id)]: { id: String(row.id), title: row.title, filename: row.filename, url: row.url },
  }
  form.assetId = row.id
}

function link(): NavLink | null {
  if (kind.value === 'heading') return null
  if (form.linkType === 'url') return { type: 'url', url: form.url }
  if (form.linkType === 'global') return { type: 'global', ref: form.globalRef }
  if (form.linkType === 'asset') return { type: 'asset', id: form.assetId! }
  return { type: form.linkType.split(':')[0] as 'entry' | 'term', id: form.entryId! }
}

function save() {
  if (!valid.value) return
  emit('save', {
    id: props.item?.id ?? crypto.randomUUID(),
    kind: kind.value,
    title: form.title.trim(),
    link: link(),
    new_tab: kind.value === 'link' ? form.newTab : (props.item?.new_tab ?? false),
    hidden: form.hidden,
    fields: form.fields,
    field_meta: form.fieldMeta,
    children: props.item?.children ?? [],
  })
}
</script>

<template>
  <Sheet :open="open" @update:open="(value) => emit('update:open', value)">
    <SheetContent size="narrow" class="gap-0">
      <SheetHeader>
        <SheetTitle>{{ item ? `Edit ${noun}` : `Add ${noun}` }}</SheetTitle>
      </SheetHeader>
      <form class="@container/panel flex-1 space-y-4 overflow-y-auto p-6" @submit.prevent="save">
        <Alert v-if="itemMessages.length" variant="destructive">
          <AlertCircle />
          <AlertDescription>
            <p v-for="message in itemMessages" :key="message">{{ message }}</p>
          </AlertDescription>
        </Alert>
        <div class="space-y-2">
          <Label for="nav-item-title">Title</Label>
          <Input id="nav-item-title" v-model="form.title" :maxlength="TITLE_MAX_LENGTH" required />
        </div>
        <template v-if="kind === 'link'">
          <div class="space-y-2">
            <Label for="nav-item-link-type">Link type</Label>
            <Select v-model="form.linkType" @update:model-value="form.entryId = null">
              <SelectTrigger id="nav-item-link-type" class="w-full"><SelectValue /></SelectTrigger>
              <SelectContent>
                <SelectItem value="url">URL</SelectItem>
                <SelectItem v-for="group in groups" :key="group.value" :value="group.value">{{
                  group.label
                }}</SelectItem>
                <SelectItem v-if="globals.length" value="global">Site setting</SelectItem>
                <SelectItem v-if="menu.assets" value="asset">File</SelectItem>
              </SelectContent>
            </Select>
          </div>
          <div v-if="form.linkType === 'url'" class="space-y-2">
            <Label for="nav-item-url">URL</Label>
            <LinkUrlInput id="nav-item-url" v-model="form.url" @submit="save" />
          </div>
          <div v-else-if="form.linkType === 'global'" class="space-y-2">
            <Label for="nav-item-global">Site setting</Label>
            <Select v-model="form.globalRef">
              <SelectTrigger id="nav-item-global" class="w-full"><SelectValue placeholder="Choose…" /></SelectTrigger>
              <SelectContent>
                <SelectGroup v-for="global in globals" :key="global.handle">
                  <SelectLabel>{{ global.title }}</SelectLabel>
                  <SelectItem
                    v-for="field in global.fields"
                    :key="field.handle"
                    :value="`global:${global.handle}.${field.handle}`"
                    >{{ field.display }}</SelectItem
                  >
                </SelectGroup>
              </SelectContent>
            </Select>
            <p v-if="pickedGlobal" class="truncate text-xs text-muted-foreground">
              {{
                pickedGlobal.field.address
                  ? `Links to ${pickedGlobal.field.address}`
                  : 'This setting holds no address yet, so the link stays off the site until it has one.'
              }}
            </p>
          </div>
          <div v-else-if="form.linkType === 'asset'" class="space-y-2">
            <Label id="nav-item-file-label">File</Label>
            <div class="flex items-center gap-3">
              <div v-if="form.assetId !== null" class="min-w-0 flex-1 text-sm">
                <p class="truncate font-medium">{{ pickedFile?.title ?? 'Missing (deleted)' }}</p>
                <p v-if="pickedFile" class="truncate text-xs text-muted-foreground">{{ pickedFile.filename }}</p>
              </div>
              <Button
                type="button"
                variant="outline"
                size="sm"
                aria-describedby="nav-item-file-label"
                @click="pickingFile = true"
                >{{ form.assetId === null ? 'Choose file…' : 'Replace…' }}</Button
              >
            </div>
            <AssetSelector v-model:open="pickingFile" :max-files="1" title="Choose a file" @select="pickFile" />
          </div>
          <div v-else class="space-y-2">
            <Label>{{ pickerLabel }}</Label>
            <EntryPicker v-model="form.entryId" :entries="pickerEntries" />
          </div>
          <label class="flex items-center justify-between gap-4 text-sm">
            Open in a new tab
            <Switch v-model="form.newTab" />
          </label>
        </template>
        <label class="flex items-start justify-between gap-4 text-sm">
          <span class="flex flex-col gap-0.5">
            Hidden
            <span class="text-xs text-muted-foreground"
              >Kept here, but left off the site with everything under it.</span
            >
          </span>
          <Switch v-model="form.hidden" />
        </label>
        <PublishContainer
          v-if="itemFields.length"
          :model-value="form.fields"
          :blueprint="NO_BLUEPRINT"
          :meta="form.fieldMeta"
          :errors="itemErrors?.fields ?? {}"
          name="nav-item"
          @update:model-value="(next) => (form.fields = next)"
          @update:meta="(next) => (form.fieldMeta = next)"
        >
          <div class="border-t pt-4">
            <PublishFields :fields="itemFields" />
          </div>
        </PublishContainer>
      </form>
      <SheetFooter>
        <Button type="button" :disabled="!valid" @click="save">Save</Button>
      </SheetFooter>
    </SheetContent>
  </Sheet>
</template>
