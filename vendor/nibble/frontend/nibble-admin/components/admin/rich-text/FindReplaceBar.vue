<script setup lang="ts">
import type { Editor } from '@tiptap/core'
import { computed, nextTick, onBeforeUnmount, ref } from 'vue'
import AdminIcon from '@/components/admin/icons/AdminIcon.vue'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'

const props = defineProps<{ editor: Editor }>()
const emit = defineEmits<{ close: [] }>()

const findInput = ref<InstanceType<typeof Input> | null>(null)
const term = ref('')
const replacement = ref('')
const showReplace = ref(false)

// Tiptap mutates this storage object in place, so it must be read inside each computed, not cached in one.
const storage = () => props.editor.storage.findAndReplace
const status = computed(() => {
  const { results, currentIndex } = storage()
  if (!term.value) return ''
  if (!results.length) return 'No results'
  return `${currentIndex === null ? 0 : currentIndex + 1} of ${results.length}`
})

function search(value: string) {
  term.value = value
  props.editor.commands.setSearchTerm(value)
}
function setReplacement(value: string) {
  replacement.value = value
  props.editor.commands.setReplaceTerm(value)
}

function focus(prefill = '') {
  if (prefill) search(prefill)
  nextTick(() => {
    const input = findInput.value?.$el as HTMLInputElement | undefined
    input?.focus()
    input?.select()
  })
}
defineExpose({ focus })

function close() {
  props.editor.commands.clearSearch()
  emit('close')
}
onBeforeUnmount(() => props.editor.commands.clearSearch())

function onFindKeydown(event: KeyboardEvent) {
  if (event.key === 'Enter') {
    event.preventDefault()
    if (event.shiftKey) props.editor.commands.goToPreviousResult()
    else props.editor.commands.goToNextResult()
  } else if (event.key === 'Escape') {
    event.preventDefault()
    event.stopPropagation()
    close()
  }
}
function onReplaceKeydown(event: KeyboardEvent) {
  if (event.key === 'Enter') {
    event.preventDefault()
    props.editor.commands.replace()
  } else if (event.key === 'Escape') {
    event.preventDefault()
    event.stopPropagation()
    close()
  }
}

const toggles = computed(() => [
  {
    label: 'Match case',
    text: 'Aa',
    pressed: storage().caseSensitive,
    disabled: false,
    toggle: () => props.editor.commands.setCaseSensitive(!storage().caseSensitive),
  },
  {
    label: 'Match whole word',
    text: 'ab',
    pressed: storage().wholeWord && !storage().useRegex,
    disabled: storage().useRegex,
    toggle: () => props.editor.commands.setWholeWord(!storage().wholeWord),
  },
  {
    label: 'Use regular expression',
    text: '.*',
    pressed: storage().useRegex,
    disabled: false,
    toggle: () => props.editor.commands.setUseRegex(!storage().useRegex),
  },
])
</script>

<template>
  <div class="nib-find" role="search" aria-label="Find and replace">
    <div class="flex items-center gap-1">
      <Button
        type="button"
        variant="ghost"
        size="sm"
        class="nib-toolbar-button px-2!"
        :aria-label="showReplace ? 'Hide replace' : 'Show replace'"
        :aria-expanded="showReplace"
        :title="showReplace ? 'Hide replace' : 'Show replace'"
        @click="showReplace = !showReplace"
      >
        <AdminIcon :name="showReplace ? 'chevron-down' : 'chevron-right'" class="size-4!" />
      </Button>
      <div class="relative min-w-0 flex-1">
        <Input
          ref="findInput"
          :model-value="term"
          placeholder="Find"
          aria-label="Find"
          class="h-8 pe-20 text-sm"
          @update:model-value="(value) => search(String(value))"
          @keydown="onFindKeydown"
        />
        <span
          class="pointer-events-none absolute inset-y-0 end-2.5 flex items-center text-xs text-gray-500 tabular-nums"
          aria-live="polite"
          >{{ status }}</span
        >
      </div>
      <Button
        v-for="option in toggles"
        :key="option.label"
        type="button"
        variant="ghost"
        size="sm"
        :class="['nib-toolbar-button px-2! font-mono text-xs', { active: option.pressed }]"
        :aria-label="option.label"
        :aria-pressed="option.pressed"
        :title="option.label"
        :disabled="option.disabled"
        @mousedown.prevent
        @click="option.toggle"
      >
        {{ option.text }}
      </Button>
      <Button
        type="button"
        variant="ghost"
        size="sm"
        class="nib-toolbar-button px-2!"
        aria-label="Previous match"
        title="Previous match (Shift+Enter)"
        :disabled="!storage().results.length"
        @mousedown.prevent
        @click="editor.commands.goToPreviousResult()"
      >
        <AdminIcon name="chevron-up" class="size-4!" />
      </Button>
      <Button
        type="button"
        variant="ghost"
        size="sm"
        class="nib-toolbar-button px-2!"
        aria-label="Next match"
        title="Next match (Enter)"
        :disabled="!storage().results.length"
        @mousedown.prevent
        @click="editor.commands.goToNextResult()"
      >
        <AdminIcon name="chevron-down" class="size-4!" />
      </Button>
      <Button
        type="button"
        variant="ghost"
        size="sm"
        class="nib-toolbar-button px-2!"
        aria-label="Close find"
        title="Close (Esc)"
        @click="close"
      >
        <AdminIcon name="x" class="size-3.5!" />
      </Button>
    </div>
    <div v-if="showReplace" class="flex items-center gap-1 ps-9">
      <Input
        :model-value="replacement"
        placeholder="Replace"
        aria-label="Replace"
        class="h-8 min-w-0 flex-1 text-sm"
        @update:model-value="(value) => setReplacement(String(value))"
        @keydown="onReplaceKeydown"
      />
      <Button
        type="button"
        variant="outline"
        size="sm"
        :disabled="!storage().results.length"
        @mousedown.prevent
        @click="editor.commands.replace()"
        >Replace</Button
      >
      <Button
        type="button"
        variant="outline"
        size="sm"
        :disabled="!storage().results.length"
        @mousedown.prevent
        @click="editor.commands.replaceAll()"
        >Replace all</Button
      >
    </div>
  </div>
</template>
