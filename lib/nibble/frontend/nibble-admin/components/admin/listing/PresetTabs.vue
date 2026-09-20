<script setup lang="ts">
import { Link, router } from '@inertiajs/vue3'
import { Plus, X } from '@lucide/vue'
import { computed, ref } from 'vue'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Popover, PopoverContent, PopoverTrigger } from '@/components/ui/popover'
import { setPreferenceNow } from '@/lib/preferences'
import type { ListingPreset } from './types'

const props = defineProps<{
  handle: string
  presets: ListingPreset[]
  currentQuery: Record<string, string | string[]>
}>()

function toQueryString(query: Record<string, string | string[]>) {
  const params = new URLSearchParams()
  for (const [key, value] of Object.entries(query)) {
    if (Array.isArray(value)) value.forEach((v) => params.append(`${key}[]`, v))
    else params.set(key, value)
  }
  return params.toString()
}

const pathname = window.location.pathname
function href(query: Record<string, string | string[]>) {
  const qs = toQueryString(query)
  return qs ? `${pathname}?${qs}` : pathname
}

function matches(query: Record<string, string | string[]>) {
  const keys = new Set([...Object.keys(query), ...Object.keys(props.currentQuery)])
  return [...keys].every(
    (key) => JSON.stringify(query[key] ?? null) === JSON.stringify(props.currentQuery[key] ?? null),
  )
}

const isAllActive = computed(() => Object.keys(props.currentQuery).length === 0)

async function persist(customPresets: ListingPreset[]) {
  await setPreferenceNow(
    `listings.${props.handle}.presets`,
    customPresets.map(({ handle, label, query }) => ({ handle, label, query })),
  )
  router.reload({ only: ['listing'] })
}

const saving = ref(false)
const label = ref('')
function save() {
  const trimmed = label.value.trim()
  if (!trimmed) return

  const handle = trimmed.toLowerCase().replace(/[^a-z0-9]+/g, '-') || 'view'
  const custom = props.presets.filter((p) => !p.built_in)
  persist([...custom, { handle, label: trimmed, query: props.currentQuery, built_in: false }])
  label.value = ''
  saving.value = false
}

function remove(preset: ListingPreset) {
  persist(props.presets.filter((p) => !p.built_in && p.handle !== preset.handle))
}
</script>

<template>
  <div
    class="-mt-2 flex flex-wrap items-center gap-x-4 border-b border-gray-200 text-sm text-gray-500 dark:border-gray-700"
  >
    <Link
      :href="pathname"
      :class="[
        'relative translate-y-px px-2 py-1 hover:text-gray-600 dark:hover:text-gray-400',
        isAllActive &&
          'text-gray-900 after:absolute after:inset-x-0 after:bottom-0 after:h-px after:bg-black dark:text-gray-200 dark:after:bg-white',
      ]"
      >All</Link
    >
    <div v-for="preset in presets" :key="preset.handle" class="group flex items-center">
      <Link
        :href="href(preset.query)"
        :class="[
          'relative translate-y-px px-2 py-1 hover:text-gray-600 dark:hover:text-gray-400',
          matches(preset.query) &&
            'text-gray-900 after:absolute after:inset-x-0 after:bottom-0 after:h-px after:bg-black dark:text-gray-200 dark:after:bg-white',
        ]"
        >{{ preset.label }}</Link
      >
      <button
        v-if="!preset.built_in"
        type="button"
        class="-ml-1 hidden text-gray-400 group-hover:inline-flex"
        :aria-label="`Delete ${preset.label}`"
        @click="remove(preset)"
      >
        <X class="size-3" />
      </button>
    </div>
    <Popover v-model:open="saving">
      <PopoverTrigger as-child>
        <Button variant="subtle" size="xs" class="mb-1"><Plus /> Save view</Button>
      </PopoverTrigger>
      <PopoverContent class="w-64">
        <form class="flex gap-2" @submit.prevent="save">
          <Input v-model="label" placeholder="View name" autofocus />
          <Button type="submit" size="sm" :disabled="!label.trim()">Save</Button>
        </form>
      </PopoverContent>
    </Popover>
  </div>
</template>
