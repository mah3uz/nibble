<script setup lang="ts">
import { ChevronDown, ChevronRight, ExternalLink, RotateCcw } from '@lucide/vue'
import { ref } from 'vue'
import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import { fieldDiff } from '@/lib/field-diff'
import { humanize } from '@/lib/utils'

export type Version = {
  id: number
  label: string
  created_at: string
  author: string | null
  restorable: boolean
  message: string | null
  changes: Record<string, [unknown, unknown]>
}

const props = defineProps<{ version: Version; previewUrl: string }>()
const emit = defineEmits<{ restore: [] }>()

const when = (iso: string) => new Date(iso).toLocaleTimeString('en-AU', { hour: 'numeric', minute: '2-digit' })
const fields = () => Object.keys(props.version.changes)
const diffs = () =>
  Object.entries(props.version.changes).map(([field, [before, after]]) => ({ field, diff: fieldDiff(before, after) }))

const expanded = ref(false)
</script>

<template>
  <div class="space-y-2 rounded-md border p-3">
    <div class="flex flex-wrap items-center justify-between gap-2">
      <button
        type="button"
        class="flex min-w-0 flex-1 items-center gap-2 text-left text-sm"
        :disabled="!fields().length"
        @click="expanded = !expanded"
      >
        <component
          :is="expanded ? ChevronDown : ChevronRight"
          v-if="fields().length"
          class="size-4 shrink-0 text-muted-foreground"
        />
        <Badge variant="secondary">{{ version.label }}</Badge>
        <span class="font-medium">{{ when(version.created_at) }}</span>
        <span class="truncate text-muted-foreground">by {{ version.author ?? 'import or system' }}</span>
      </button>
      <div class="flex shrink-0 items-center gap-1">
        <Button as-child type="button" variant="ghost" size="icon-sm" title="Preview this version">
          <a :href="previewUrl" target="_blank" rel="noopener"><ExternalLink /></a>
        </Button>
        <Button v-if="version.restorable" type="button" variant="outline" size="sm" @click="emit('restore')"
          ><RotateCcw /> Restore</Button
        >
      </div>
    </div>

    <p v-if="version.message" class="text-sm italic">“{{ version.message }}”</p>

    <p v-if="!fields().length" class="text-xs text-muted-foreground">No content changes.</p>
    <p v-else-if="!expanded" class="text-xs text-muted-foreground">{{ fields().map(humanize).join(', ') }}</p>

    <div v-else class="space-y-3">
      <div v-for="{ field, diff } in diffs()" :key="field" class="space-y-1">
        <div class="text-xs font-medium">{{ humanize(field) }}</div>
        <div v-if="diff.inline" class="flex flex-wrap items-baseline gap-2 text-sm">
          <del v-if="diff.before" class="bg-red-50 px-1 text-red-700 dark:bg-red-950 dark:text-red-300">{{
            diff.before
          }}</del>
          <span v-if="diff.before" class="text-muted-foreground">→</span>
          <ins class="bg-green-50 px-1 text-green-800 no-underline dark:bg-green-950 dark:text-green-300">{{
            diff.after || '(empty)'
          }}</ins>
        </div>
        <pre v-else class="max-h-72 overflow-auto rounded-md bg-muted p-2 text-xs leading-5"><template
              v-for="(line, index) in diff.lines"
              :key="index"
            ><div v-if="line.kind === 'skipped'" class="text-muted-foreground italic">… {{ line.count }} unchanged lines</div><div
                v-else
                :class="{
                  'bg-red-100 text-red-800 dark:bg-red-950 dark:text-red-300': line.kind === 'removed',
                  'bg-green-100 text-green-900 dark:bg-green-950 dark:text-green-300': line.kind === 'added',
                }"
              >{{ line.kind === 'removed' ? '-' : line.kind === 'added' ? '+' : ' ' }} {{ line.text }}</div></template></pre>
      </div>
    </div>
  </div>
</template>
