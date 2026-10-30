<script setup lang="ts">
import { AlertCircle, X } from '@lucide/vue'
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
import DateFieldtype from '@nibble-cp/fieldtypes/components/DateFieldtype.vue'
import PublishContainer from '@nibble-cp/publish/PublishContainer.vue'
import PublishFields from '@nibble-cp/publish/PublishFields.vue'
import { useNavEditor } from './context'
import EntryPicker from './EntryPicker.vue'
import { QUERY_SORTS } from './tree'
import type { NavEntry, NavKind, NavLink, NavQuery, NavTreeItem } from './types'

const props = defineProps<{ open: boolean; item: NavTreeItem | null; kind: NavKind }>()
const emit = defineEmits<{ save: [NavTreeItem]; 'update:open': [boolean] }>()
const { menu, entries, queryRecords, assets, errors } = useNavEditor()

const TITLE_MAX_LENGTH = 60
const URL_FORMAT = /^(https:\/\/\S+|\/\S*)$/
const NO_BLUEPRINT = { handle: 'item', title: '', tabs: [] }
const QUERY_LIMIT = 50
const DATE_CONFIG = { type: 'date', time_enabled: true, full_width: true }

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
  collection: '',
  parent: null as number | null,
  term: 'any',
  sort: 'default',
  limit: '',
  showFrom: null as string | null,
  showUntil: null as string | null,
})
const pickingFile = ref(false)

const kind = computed(() => props.item?.kind ?? props.kind)
const custom = computed(() => menu.kinds?.find((one) => one.handle === kind.value))
const noun = computed(() =>
  kind.value === 'heading' ? 'heading' : kind.value === 'query' ? 'list of pages' : (custom.value?.display ?? 'link'),
)
const linkMode = computed(() => (kind.value === 'link' ? 'required' : (custom.value?.link ?? 'none')))
const globals = computed(() => menu.globals ?? [])
const itemFields = computed(() => {
  const own = custom.value?.fields ?? []
  const handles = new Set(own.map((field) => field.handle))
  return [...own, ...(menu.item_fields ?? []).filter((field) => !handles.has(field.handle))]
})
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
    form.linkType = linked
      ? groupKey(linked)
      : link?.type === 'global' || link?.type === 'asset' || link?.type === 'url'
        ? link.type
        : linkMode.value === 'optional'
          ? 'none'
          : 'url'
    form.url = link?.type === 'url' ? link.url : ''
    form.entryId = linked?.id ?? null
    form.globalRef = link?.type === 'global' ? link.ref : ''
    form.assetId = link?.type === 'asset' ? link.id : null
    form.newTab = item?.new_tab ?? false
    form.hidden = item?.hidden ?? false
    form.fields = { ...(item?.fields ?? {}) }
    form.fieldMeta = { ...(item?.field_meta ?? {}) }
    const query = item?.query
    form.collection = query?.collection ?? (menu.queries?.length === 1 ? menu.queries[0]!.handle : '')
    form.parent = query?.parent ?? null
    form.term = query?.term ? `${query.term.taxonomy}:${query.term.id}` : 'any'
    form.sort = query?.sort ?? 'default'
    form.limit = query?.limit === undefined ? '' : String(query.limit)
    form.showFrom = item?.show_from ?? null
    form.showUntil = item?.show_until ?? null
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

const source = computed(() => menu.queries?.find((one) => one.handle === form.collection))
const parentEntries = computed(() =>
  queryRecords.filter((record) => record.type === 'entry' && record.group === form.collection),
)
const termGroups = computed(() =>
  (source.value?.taxonomies ?? []).map((taxonomy) => ({
    ...taxonomy,
    terms: queryRecords.filter((record) => record.type === 'term' && record.group === taxonomy.handle),
  })),
)
const sorts = computed(() => {
  const offered = QUERY_SORTS.filter((sort) => !sort.structured || source.value?.structured)
  return form.sort === 'default' || offered.some((sort) => sort.value === form.sort)
    ? offered
    : [...offered, { value: form.sort, label: `Sorted by ${form.sort}` }]
})
const limit = computed(() => (String(form.limit).trim() === '' ? undefined : Number(form.limit)))
const limitValid = computed(
  () => limit.value === undefined || (Number.isInteger(limit.value) && limit.value >= 1 && limit.value <= QUERY_LIMIT),
)
const queryValid = computed(() => kind.value !== 'query' || (!!source.value && limitValid.value))
const datesInOrder = computed(
  () => !form.showFrom || !form.showUntil || Date.parse(form.showFrom) < Date.parse(form.showUntil),
)

function pickCollection() {
  form.parent = null
  form.term = 'any'
  if (!sorts.value.some((sort) => sort.value === form.sort)) form.sort = 'default'
}

function query(): NavQuery | null {
  if (kind.value !== 'query') return props.item?.query ?? null
  const [taxonomy, id] = form.term.split(':')
  return {
    collection: form.collection,
    ...(form.parent !== null && { parent: form.parent }),
    ...(form.term !== 'any' && { term: { taxonomy: taxonomy!, id: Number(id) } }),
    ...(form.sort !== 'default' && { sort: form.sort }),
    ...(limit.value !== undefined && { limit: limit.value }),
  }
}

const linkValid = computed(() => {
  if (linkMode.value === 'none' || form.linkType === 'none') return true
  if (form.linkType === 'url') return URL_FORMAT.test(form.url)
  if (form.linkType === 'global') return !!pickedGlobal.value
  if (form.linkType === 'asset') return form.assetId !== null
  return form.entryId !== null
})
const valid = computed(
  () =>
    form.title.trim().length > 0 &&
    form.title.length <= TITLE_MAX_LENGTH &&
    linkValid.value &&
    queryValid.value &&
    datesInOrder.value,
)

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
  if (linkMode.value === 'none' && !custom.value && kind.value !== 'heading' && kind.value !== 'query')
    return props.item?.link ?? null
  if (linkMode.value === 'none' || form.linkType === 'none') return null
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
    new_tab: linkMode.value !== 'none' ? form.newTab && form.linkType !== 'none' : (props.item?.new_tab ?? false),
    hidden: form.hidden,
    query: query(),
    show_from: form.showFrom,
    show_until: form.showUntil,
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
        <template v-if="kind === 'query'">
          <div class="space-y-2">
            <Label for="nav-item-collection">Pages from</Label>
            <Select v-model="form.collection" @update:model-value="pickCollection">
              <SelectTrigger id="nav-item-collection" class="w-full"
                ><SelectValue placeholder="Choose a collection…"
              /></SelectTrigger>
              <SelectContent>
                <SelectItem v-for="one in menu.queries" :key="one.handle" :value="one.handle">{{
                  one.title
                }}</SelectItem>
              </SelectContent>
            </Select>
          </div>
          <div v-if="source?.structured" class="space-y-2">
            <Label id="nav-item-parent-label">Under the page</Label>
            <div class="flex items-center gap-2">
              <EntryPicker
                v-model="form.parent"
                :entries="parentEntries"
                placeholder="Any page"
                aria-labelledby="nav-item-parent-label"
              />
              <Button
                v-if="form.parent !== null"
                type="button"
                variant="ghost"
                size="icon-sm"
                aria-label="Clear the page"
                @click="form.parent = null"
                ><X
              /></Button>
            </div>
            <p class="text-xs text-muted-foreground">Leave empty to list from the whole collection.</p>
          </div>
          <div v-if="termGroups.length" class="space-y-2">
            <Label for="nav-item-term">Only pages in</Label>
            <Select v-model="form.term">
              <SelectTrigger id="nav-item-term" class="w-full"><SelectValue /></SelectTrigger>
              <SelectContent>
                <SelectItem value="any">Any term</SelectItem>
                <SelectGroup v-for="taxonomy in termGroups" :key="taxonomy.handle">
                  <SelectLabel>{{ taxonomy.title }}</SelectLabel>
                  <SelectItem v-for="term in taxonomy.terms" :key="term.id" :value="`${taxonomy.handle}:${term.id}`">{{
                    term.title
                  }}</SelectItem>
                </SelectGroup>
              </SelectContent>
            </Select>
          </div>
          <div class="grid grid-cols-[1fr_6rem] gap-3">
            <div class="space-y-2">
              <Label for="nav-item-sort">Order</Label>
              <Select v-model="form.sort">
                <SelectTrigger id="nav-item-sort" class="w-full"><SelectValue /></SelectTrigger>
                <SelectContent>
                  <SelectItem value="default">The collection's own order</SelectItem>
                  <SelectItem v-for="sort in sorts" :key="sort.value" :value="sort.value">{{ sort.label }}</SelectItem>
                </SelectContent>
              </Select>
            </div>
            <div class="space-y-2">
              <Label for="nav-item-limit">Up to</Label>
              <Input
                id="nav-item-limit"
                v-model="form.limit"
                type="number"
                inputmode="numeric"
                :min="1"
                :max="QUERY_LIMIT"
                :placeholder="String(QUERY_LIMIT)"
                :aria-invalid="!limitValid || undefined"
              />
            </div>
          </div>
          <p class="text-xs" :class="limitValid ? 'text-muted-foreground' : 'text-destructive'">
            {{
              limitValid
                ? `The site fills this with up to ${limit ?? QUERY_LIMIT} published pages, and keeps it up to date.`
                : `Choose from 1 to ${QUERY_LIMIT} pages.`
            }}
          </p>
        </template>
        <template v-if="linkMode !== 'none'">
          <div class="space-y-2">
            <Label for="nav-item-link-type">Link type</Label>
            <Select v-model="form.linkType" @update:model-value="form.entryId = null">
              <SelectTrigger id="nav-item-link-type" class="w-full"><SelectValue /></SelectTrigger>
              <SelectContent>
                <SelectItem v-if="linkMode === 'optional'" value="none">No link</SelectItem>
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
          <div v-else-if="form.linkType !== 'none'" class="space-y-2">
            <Label id="nav-item-entry-label">{{ pickerLabel }}</Label>
            <EntryPicker v-model="form.entryId" :entries="pickerEntries" aria-labelledby="nav-item-entry-label" />
          </div>
          <label v-if="form.linkType !== 'none'" class="flex items-center justify-between gap-4 text-sm">
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
        <div class="space-y-2" role="group" aria-labelledby="nav-item-show-from-label">
          <Label id="nav-item-show-from-label" for="nav-item-show-from">Show from</Label>
          <DateFieldtype
            id="nav-item-show-from"
            handle="show_from"
            :value="form.showFrom"
            :config="DATE_CONFIG"
            @update:value="(value: string | null) => (form.showFrom = value)"
          />
        </div>
        <div class="space-y-2" role="group" aria-labelledby="nav-item-show-until-label">
          <Label id="nav-item-show-until-label" for="nav-item-show-until">Show until</Label>
          <DateFieldtype
            id="nav-item-show-until"
            handle="show_until"
            :value="form.showUntil"
            :config="DATE_CONFIG"
            @update:value="(value: string | null) => (form.showUntil = value)"
          />
          <p class="text-xs" :class="datesInOrder ? 'text-muted-foreground' : 'text-destructive'">
            {{
              datesInOrder
                ? 'Leave both empty to show it all the time.'
                : 'Choose a show until date after its show from date.'
            }}
          </p>
        </div>
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
