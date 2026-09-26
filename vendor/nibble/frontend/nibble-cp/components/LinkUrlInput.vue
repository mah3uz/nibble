<script setup lang="ts">
import { ref, watch } from 'vue'
import { Input } from '@/components/ui/input'

type Suggestion = { title: string; path: string; type: 'page' | 'post'; status: 'draft' | 'scheduled' | 'published' }

const STATUS_DOT = { draft: 'bg-muted-foreground/40', scheduled: 'bg-amber-500', published: 'bg-green-500' }

const href = defineModel<string>({ required: true })
defineProps<{ id: string }>()
const emit = defineEmits<{ submit: [] }>()

const suggestions = ref<Suggestion[]>([])
const highlighted = ref(-1)
let requestId = 0
let picked = false

watch(href, (value) => {
  if (picked) {
    picked = false
    return
  }
  highlighted.value = -1
  if (!value.startsWith('/')) {
    requestId++
    suggestions.value = []
    return
  }
  const id = ++requestId
  setTimeout(async () => {
    if (id !== requestId) return
    const response = await fetch(`/cp/link_suggestions?q=${encodeURIComponent(value)}`, {
      headers: { Accept: 'application/json' },
    })
    if (id !== requestId || !response.ok) return
    suggestions.value = (await response.json()).suggestions
  }, 150)
})

function pick(suggestion: Suggestion) {
  picked = true
  requestId++
  href.value = suggestion.path
  suggestions.value = []
}

function onKeydown(event: KeyboardEvent) {
  const count = suggestions.value.length
  if (event.key === 'ArrowDown' && count) {
    event.preventDefault()
    highlighted.value = (highlighted.value + 1) % count
  } else if (event.key === 'ArrowUp' && count) {
    event.preventDefault()
    highlighted.value = (highlighted.value - 1 + count) % count
  } else if (event.key === 'Escape' && count) {
    event.preventDefault()
    event.stopPropagation()
    suggestions.value = []
  } else if (event.key === 'Enter') {
    event.preventDefault()
    const suggestion = suggestions.value[highlighted.value]
    if (suggestion) pick(suggestion)
    else emit('submit')
  }
}
</script>

<template>
  <div>
    <Input
      :id="id"
      v-model="href"
      placeholder="https:// or / for pages and posts"
      autocomplete="off"
      role="combobox"
      :aria-expanded="suggestions.length > 0"
      :aria-controls="`${id}-suggestions`"
      :aria-activedescendant="highlighted >= 0 ? `${id}-suggestion-${highlighted}` : undefined"
      @keydown="onKeydown"
    />
    <ul
      v-if="suggestions.length"
      :id="`${id}-suggestions`"
      role="listbox"
      class="mt-1 max-h-48 overflow-y-auto rounded-lg border border-gray-200 bg-white p-1 dark:border-gray-700 dark:bg-gray-900"
    >
      <li
        v-for="(suggestion, index) in suggestions"
        :id="`${id}-suggestion-${index}`"
        :key="`${suggestion.type}-${suggestion.path}`"
        role="option"
        :aria-selected="index === highlighted"
        :class="[
          'flex cursor-pointer items-center gap-2 rounded-md px-2 py-1.5 text-sm',
          index === highlighted ? 'bg-gray-100 dark:bg-gray-800' : 'hover:bg-gray-50 dark:hover:bg-gray-850',
        ]"
        @mousedown.prevent="pick(suggestion)"
        @mouseenter="highlighted = index"
      >
        <span
          :class="['size-2 shrink-0 rounded-full', STATUS_DOT[suggestion.status]]"
          :title="suggestion.status"
          role="img"
          :aria-label="suggestion.status"
        />
        <span class="min-w-0 flex-1">
          <span class="block truncate text-gray-925 dark:text-white">{{ suggestion.title }}</span>
          <span class="block truncate text-xs text-gray-500">{{ suggestion.path }}</span>
        </span>
        <span class="shrink-0 text-xs text-gray-500 capitalize">{{ suggestion.type }}</span>
      </li>
    </ul>
  </div>
</template>
