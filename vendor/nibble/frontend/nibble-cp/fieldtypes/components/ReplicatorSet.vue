<script setup lang="ts">
import {
  AlertCircle,
  ArrowDown,
  ArrowUp,
  ChevronDown,
  ChevronRight,
  ClipboardCopy,
  Copy,
  Eye,
  EyeOff,
  GripVertical,
  MoreHorizontal,
  Trash2,
} from '@lucide/vue'
import { computed } from 'vue'
import CpIcon from '@/components/cp/icons/CpIcon.vue'
import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from '@/components/ui/dropdown-menu'
import PublishFields from '../../publish/PublishFields.vue'
import { useContainer } from '../../publish/context'
import { setPreview } from '../replicatorSets'
import type { PublishSet, PublishSetGroup } from '../types'
import SetPicker from './SetPicker.vue'

const props = defineProps<{
  row: Record<string, unknown> & { _id: string; type: string; enabled?: boolean }
  set: PublishSet | undefined
  groups: PublishSetGroup[]
  collapsed: boolean
  readOnly: boolean
  canAdd: boolean
  canDuplicate: boolean
  menu?: boolean
  canMoveUp?: boolean
  canMoveDown?: boolean
  fieldPathPrefix: string
  metaPathPrefix: string
}>()
const emit = defineEmits<{
  toggle: []
  duplicate: []
  remove: []
  move: [delta: -1 | 1]
  copy: []
  enable: [enabled: boolean]
  addBelow: [handle: string]
  pasteBelow: []
}>()
const { errors } = useContainer()

const preview = computed(() => setPreview(props.set?.fields ?? [], props.row))
const name = computed(() => props.set?.display ?? props.row.type)
const toggleLabel = computed(() => (props.collapsed && preview.value ? `${name.value}: ${preview.value}` : name.value))
const hasError = computed(() => Object.keys(errors.value).some((path) => path.startsWith(`${props.fieldPathPrefix}.`)))
</script>

<template>
  <div
    class="rounded-lg border border-gray-300 bg-white shadow-ui-sm dark:border-gray-700 dark:bg-gray-900"
    :class="{ 'opacity-60': row.enabled === false }"
    :data-set="row.type"
  >
    <div class="flex items-center gap-2 rounded-t-lg bg-gray-50 px-2 py-1.5 dark:bg-gray-850">
      <GripVertical v-if="!readOnly" class="drag-handle size-4 shrink-0 cursor-grab text-muted-foreground" />
      <button
        type="button"
        class="flex min-w-0 flex-1 items-center gap-1.5 text-left text-sm"
        :aria-expanded="!collapsed"
        :aria-label="toggleLabel"
        @click="emit('toggle')"
      >
        <ChevronDown v-if="!collapsed" class="size-4 shrink-0" /><ChevronRight v-else class="size-4 shrink-0" />
        <CpIcon v-if="set?.icon" :name="set.icon" class="size-4 text-muted-foreground" />
        <span class="font-medium">{{ name }}</span>
        <span v-if="collapsed && preview" class="truncate text-muted-foreground">— {{ preview }}</span>
      </button>
      <Badge v-if="set?.badge" variant="secondary">{{ set.badge }}</Badge>
      <AlertCircle v-if="hasError" class="size-4 shrink-0 text-destructive" aria-label="Has errors" />
      <SetPicker
        v-if="canAdd"
        :groups="groups"
        :disabled="readOnly"
        icon-only
        :can-paste="menu"
        label="Add block below"
        @pick="(handle) => emit('addBelow', handle)"
        @paste="emit('pasteBelow')"
      />
      <Button
        type="button"
        size="icon-sm"
        variant="ghost"
        :disabled="readOnly"
        :aria-label="row.enabled === false ? 'Turn block on' : 'Turn block off'"
        @click="emit('enable', row.enabled === false)"
      >
        <EyeOff v-if="row.enabled === false" /><Eye v-else />
      </Button>
      <Button
        type="button"
        size="icon-sm"
        variant="ghost"
        :disabled="readOnly || !canDuplicate"
        aria-label="Duplicate block"
        @click="emit('duplicate')"
        ><Copy
      /></Button>
      <Button
        type="button"
        size="icon-sm"
        variant="ghost"
        :disabled="readOnly"
        aria-label="Remove block"
        @click="emit('remove')"
        ><Trash2
      /></Button>
      <DropdownMenu v-if="menu">
        <DropdownMenuTrigger as-child>
          <Button type="button" size="icon-sm" variant="ghost" :aria-label="`Actions for ${name}`"
            ><MoreHorizontal
          /></Button>
        </DropdownMenuTrigger>
        <DropdownMenuContent align="end" class="min-w-44">
          <DropdownMenuItem :disabled="!canMoveUp" @select="emit('move', -1)"><ArrowUp />Move up</DropdownMenuItem>
          <DropdownMenuItem :disabled="!canMoveDown" @select="emit('move', 1)"><ArrowDown />Move down</DropdownMenuItem>
          <DropdownMenuSeparator />
          <DropdownMenuItem @select="emit('copy')"><ClipboardCopy />Copy block</DropdownMenuItem>
        </DropdownMenuContent>
      </DropdownMenu>
    </div>
    <div v-if="!collapsed" class="border-t p-4">
      <PublishFields
        v-if="set"
        :fields="set.fields"
        :field-path-prefix="fieldPathPrefix"
        :meta-path-prefix="metaPathPrefix"
        :read-only="readOnly"
      />
      <p v-else class="text-sm text-red-600">This block type is no longer available, so it can't be edited. Remove it, or ask a developer to bring it back.</p>
    </div>
  </div>
</template>
