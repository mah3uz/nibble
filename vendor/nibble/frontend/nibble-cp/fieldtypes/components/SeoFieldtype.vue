<script setup lang="ts">
import { computed } from 'vue'
import { Input } from '@/components/ui/input'
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select'
import { Switch } from '@/components/ui/switch'
import { Textarea } from '@/components/ui/textarea'
import { fieldtypeEmits, fieldtypeProps, useFieldtype } from '../useFieldtype'
import { useSiblings } from '../useSiblings'
import AssetsFieldtype from './AssetsFieldtype.vue'

type Seo = {
  title: string | null
  description: string | null
  canonical: string | null
  og_image: { asset: string } | null
  exact_title: boolean
  noindex: boolean
  nositemap: boolean
  schema_type: string | null
}

const props = defineProps(fieldtypeProps)
const emit = defineEmits(fieldtypeEmits)
const { update, updateDebounced, isReadOnly, expose } = useFieldtype(emit, props)
defineExpose(expose)

const siblings = useSiblings(props)
const seo = computed(
  () => ({ exact_title: false, noindex: false, nositemap: false, ...((props.value as Partial<Seo>) ?? {}) }) as Seo,
)
const set = (key: keyof Seo, value: unknown, debounce = true) =>
  (debounce ? updateDebounced : update)({ ...seo.value, [key]: value })

const fallbackTitle = computed(() => String(siblings.value.title ?? ''))
const fallbackDescription = computed(() => String(siblings.value.excerpt ?? ''))
const title = computed(() => seo.value.title || fallbackTitle.value)
const description = computed(() => seo.value.description || fallbackDescription.value)
const titleLimit = computed(() => Number(props.config.title_limit) || 60)
const descriptionLimit = computed(() => Number(props.config.description_limit) || 160)
const schemaTypes = computed(() => (props.config.schema_types as string[]) ?? [])
const typeLabels: Record<string, string> = {
  WebPage: 'Web page',
  BlogPosting: 'Blog post',
  FAQPage: 'FAQ page',
  Organization: 'Organisation',
  LocalBusiness: 'Local business',
}
const NONE = '__none__'
const IMAGE_TYPES = ['jpg', 'jpeg', 'png', 'webp', 'gif', 'avif']
const imageConfig = computed(() => ({
  ...props.config,
  type: 'assets',
  max_files: 1,
  alt: 'none',
  allowed_types: IMAGE_TYPES,
}))
</script>

<template>
  <div :id="id" class="space-y-3">
    <div class="rounded-md border p-3">
      <div class="truncate text-base text-blue-700 dark:text-blue-400">{{ title || 'Untitled' }}</div>
      <div class="line-clamp-2 text-sm text-muted-foreground">{{ description || 'No description' }}</div>
    </div>
    <div class="space-y-2">
      <label class="flex items-center justify-between text-sm"
        >Title <span class="text-xs text-muted-foreground">({{ title.length }}/{{ titleLimit }})</span></label
      >
      <Input
        :model-value="seo.title ?? ''"
        :disabled="isReadOnly"
        :placeholder="fallbackTitle"
        @update:model-value="(text) => set('title', String(text))"
      />
    </div>
    <label class="flex items-center justify-between text-sm">
      Use this title as written
      <Switch
        :model-value="seo.exact_title"
        :disabled="isReadOnly"
        @update:model-value="(on) => set('exact_title', on, false)"
      />
    </label>
    <div class="space-y-2">
      <label class="flex items-center justify-between text-sm"
        >Description
        <span class="text-xs text-muted-foreground">({{ description.length }}/{{ descriptionLimit }})</span></label
      >
      <Textarea
        :model-value="seo.description ?? ''"
        rows="3"
        :disabled="isReadOnly"
        :placeholder="fallbackDescription"
        @update:model-value="(text) => set('description', String(text))"
      />
    </div>
    <div class="space-y-2">
      <label class="text-sm">Main address (if this page copies another)</label>
      <Input
        :model-value="seo.canonical ?? ''"
        :disabled="isReadOnly"
        placeholder="This page's own URL"
        @update:model-value="(text) => set('canonical', String(text))"
      />
    </div>
    <div class="space-y-2">
      <label class="text-sm">Share image</label>
      <AssetsFieldtype
        id="og_image"
        handle="og_image"
        :value="seo.og_image"
        :config="imageConfig"
        :meta="meta"
        :read-only="isReadOnly"
        @update:value="(image) => set('og_image', image, false)"
        @update:meta="(next) => emit('update:meta', next)"
      />
    </div>
    <div v-if="schemaTypes.length" class="space-y-2">
      <label class="text-sm">Kind of page, for search engines</label>
      <Select
        :model-value="seo.schema_type ?? NONE"
        :disabled="isReadOnly"
        @update:model-value="(type) => set('schema_type', type === NONE ? null : type, false)"
      >
        <SelectTrigger class="w-full"><SelectValue /></SelectTrigger>
        <SelectContent>
          <SelectItem :value="NONE">Default</SelectItem>
          <SelectItem v-for="type in schemaTypes" :key="type" :value="type">{{ typeLabels[type] ?? type }}</SelectItem>
        </SelectContent>
      </Select>
    </div>
    <label class="flex items-center justify-between text-sm">
      Hide from search engines
      <Switch
        :model-value="seo.noindex"
        :disabled="isReadOnly"
        @update:model-value="(on) => set('noindex', on, false)"
      />
    </label>
    <label class="flex items-center justify-between text-sm">
      Leave out of the sitemap
      <Switch
        :model-value="seo.nositemap"
        :disabled="isReadOnly"
        @update:model-value="(on) => set('nositemap', on, false)"
      />
    </label>
  </div>
</template>
