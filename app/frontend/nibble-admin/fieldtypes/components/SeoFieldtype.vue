<script setup lang="ts">
import { computed } from 'vue'
import { Input } from '@/components/ui/input'
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select'
import { Switch } from '@/components/ui/switch'
import { Textarea } from '@/components/ui/textarea'
import { fieldtypeEmits, fieldtypeProps, useFieldtype } from '../useFieldtype'
import { useSiblings } from '../useSiblings'

type Seo = {
  title: string | null
  description: string | null
  canonical: string | null
  og_image: string | null
  noindex: boolean
  schema_type: string | null
}

const props = defineProps(fieldtypeProps)
const emit = defineEmits(fieldtypeEmits)
const { update, updateDebounced, isReadOnly, expose } = useFieldtype(emit, props)
defineExpose(expose)

const siblings = useSiblings(props)
const seo = computed(() => ({ noindex: false, ...((props.value as Partial<Seo>) ?? {}) }) as Seo)
const set = (key: keyof Seo, value: unknown, debounce = true) =>
  (debounce ? updateDebounced : update)({ ...seo.value, [key]: value })

const fallbackTitle = computed(() => String(siblings.value.title ?? ''))
const fallbackDescription = computed(() => String(siblings.value.excerpt ?? ''))
const title = computed(() => seo.value.title || fallbackTitle.value)
const description = computed(() => seo.value.description || fallbackDescription.value)
const titleLimit = computed(() => Number(props.config.title_limit) || 60)
const descriptionLimit = computed(() => Number(props.config.description_limit) || 160)
const schemaTypes = computed(() => (props.config.schema_types as string[]) ?? [])
const NONE = '__none__'
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
      <label class="text-sm">Canonical URL</label>
      <Input
        :model-value="seo.canonical ?? ''"
        :disabled="isReadOnly"
        placeholder="This page's own URL"
        @update:model-value="(text) => set('canonical', String(text))"
      />
    </div>
    <div class="space-y-2">
      <label class="text-sm">Social image URL</label>
      <Input
        :model-value="seo.og_image ?? ''"
        :disabled="isReadOnly"
        placeholder="Site default"
        @update:model-value="(text) => set('og_image', String(text))"
      />
    </div>
    <div v-if="schemaTypes.length" class="space-y-2">
      <label class="text-sm">Schema type</label>
      <Select
        :model-value="seo.schema_type ?? NONE"
        :disabled="isReadOnly"
        @update:model-value="(type) => set('schema_type', type === NONE ? null : type, false)"
      >
        <SelectTrigger class="w-full"><SelectValue /></SelectTrigger>
        <SelectContent>
          <SelectItem :value="NONE">Default</SelectItem>
          <SelectItem v-for="type in schemaTypes" :key="type" :value="type">{{ type }}</SelectItem>
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
  </div>
</template>
