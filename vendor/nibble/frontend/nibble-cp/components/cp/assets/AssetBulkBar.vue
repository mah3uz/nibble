<script setup lang="ts">
import { onBeforeUnmount, onMounted } from 'vue'
import CpIcon from '@/components/cp/icons/CpIcon.vue'
import { Button } from '@/components/ui/button'
import type { Abilities } from './api'

export type BulkAction =
  'copy' | 'download' | 'duplicate' | 'move' | 'rename' | 'replace' | 'reupload' | 'tag' | 'delete'

const props = defineProps<{ count: number; can: Abilities }>()
const emit = defineEmits<{ deselect: []; run: [action: BulkAction] }>()

const KEYS: Record<string, BulkAction | 'deselect'> = {
  Escape: 'deselect',
  c: 'copy',
  d: 'download',
  r: 'rename',
  e: 'replace',
  p: 'reupload',
  u: 'duplicate',
  m: 'move',
  t: 'tag',
  Backspace: 'delete',
  Delete: 'delete',
}

const SINGLE: BulkAction[] = ['copy', 'rename', 'replace', 'reupload']
const MULTIPLE: BulkAction[] = ['tag']

function allowed(action: BulkAction) {
  if (SINGLE.includes(action) && props.count !== 1) return false
  if (MULTIPLE.includes(action) && props.count < 2) return false
  if (action === 'copy') return true
  if (action === 'duplicate') return props.can.upload
  if (['move', 'tag', 'rename', 'replace', 'reupload'].includes(action)) return props.can.edit
  if (action === 'delete') return props.can.delete
  return true
}

function onKeydown(event: KeyboardEvent) {
  if (!props.count || event.metaKey || event.ctrlKey || event.altKey) return
  const target = event.target as HTMLElement
  if (target.closest('input, textarea, select, [contenteditable], [role=dialog], [role=menu]')) return
  const action = KEYS[event.key]
  if (!action) return
  event.preventDefault()
  if (action === 'deselect') emit('deselect')
  else if (allowed(action)) emit('run', action)
}

onMounted(() => window.addEventListener('keydown', onKeydown))
onBeforeUnmount(() => window.removeEventListener('keydown', onKeydown))

const kbd =
  'ms-1.5 inline-flex h-4 min-w-4 items-center justify-center rounded bg-gray-200/75 px-1 text-[0.625rem] font-semibold text-gray-600 uppercase dark:bg-gray-800 dark:text-gray-400'
</script>

<template>
  <div
    v-if="count"
    data-floating-toolbar
    class="pointer-events-none sticky inset-x-0 bottom-1 z-20 mx-auto flex w-full max-w-[95vw] justify-center sm:bottom-6"
  >
    <div
      class="pointer-events-auto rounded-xl border border-gray-300/60 bg-gray-200/55 p-1 shadow-[0_1px_16px_-2px_rgba(63,63,71,0.2)] dark:border-gray-700 dark:bg-gray-800 dark:shadow-[0_10px_15px_rgba(0,0,0,.5)] dark:inset-shadow-2xs dark:inset-shadow-white/10"
    >
      <div
        class="inline-flex flex-wrap justify-center [&>button:first-child:not(:last-child)]:rounded-e-none [&>button:last-child:not(:first-child)]:rounded-s-none [&>button:not(:first-child)]:border-s-0 [&>button:not(:first-child):not(:last-child)]:rounded-none"
      >
        <Button variant="outline" class="text-blue-500!" @click="emit('deselect')">
          {{ count === 1 ? 'Deselect 1 item' : `Deselect all ${count} items` }}
          <span :class="kbd" class="bg-blue-100/80! text-blue-600! dark:bg-blue-950! dark:text-blue-400!">Esc</span>
        </Button>
        <Button v-if="count === 1" variant="outline" @click="emit('run', 'copy')"
          >Copy URL <span :class="kbd">c</span></Button
        >
        <Button variant="outline" @click="emit('run', 'download')">Download <span :class="kbd">d</span></Button>
        <Button v-if="can.upload" variant="outline" @click="emit('run', 'duplicate')"
          >Duplicate <span :class="kbd">u</span></Button
        >
        <Button v-if="can.edit" variant="outline" @click="emit('run', 'move')">Move <span :class="kbd">m</span></Button>
        <template v-if="count === 1 && can.edit">
          <Button variant="outline" @click="emit('run', 'rename')">Rename <span :class="kbd">r</span></Button>
          <Button variant="outline" @click="emit('run', 'replace')">Replace <span :class="kbd">e</span></Button>
          <Button variant="outline" @click="emit('run', 'reupload')">Reupload <span :class="kbd">p</span></Button>
        </template>
        <Button v-if="can.edit && count > 1" variant="outline" @click="emit('run', 'tag')"
          >Tag <span :class="kbd">t</span></Button
        >
        <Button v-if="can.delete" variant="outline" class="text-red-600!" @click="emit('run', 'delete')">
          Delete
          <span :class="kbd" class="ms-0.25! bg-transparent dark:bg-transparent"
            ><CpIcon name="backspace" class="size-3.75 text-red-600 opacity-70 dark:text-red-500"
          /></span>
        </Button>
      </div>
    </div>
  </div>
</template>
