<script setup lang="ts">
import { AlertCircle, ChevronDown, ChevronRight, Copy, Eye, EyeOff, GripVertical, Trash2 } from '@lucide/vue'
import { computed } from 'vue'
import CpIcon from '@/components/cp/icons/CpIcon.vue'
import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
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
  fieldPathPrefix: string
  metaPathPrefix: string
}>()
const emit = defineEmits<{
  toggle: []
  duplicate: []
  remove: []
  enable: [enabled: boolean]
  addBelow: [handle: string]
}>()
const { errors } = useContainer()

const preview = computed(() => setPreview(props.set?.fields ?? [], props.row))
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
      <button type="button" class="flex flex-1 items-center gap-1.5 text-left text-sm" @click="emit('toggle')">
        <ChevronDown v-if="!collapsed" class="size-4 shrink-0" /><ChevronRight v-else class="size-4 shrink-0" />
        <CpIcon v-if="set?.icon" :name="set.icon" class="size-4 text-muted-foreground" />
        <span class="font-medium">{{ set?.display ?? row.type }}</span>
        <span v-if="collapsed && preview" class="truncate text-muted-foreground">— {{ preview }}</span>
      </button>
      <Badge v-if="set?.badge" variant="secondary">{{ set.badge }}</Badge>
      <AlertCircle v-if="hasError" class="size-4 shrink-0 text-destructive" aria-label="Has errors" />
      <SetPicker
        v-if="canAdd"
        :groups="groups"
        :disabled="readOnly"
        icon-only
        label="Add set below"
        @pick="(handle) => emit('addBelow', handle)"
      />
      <Button
        type="button"
        size="icon-sm"
        variant="ghost"
        :disabled="readOnly"
        :aria-label="row.enabled === false ? 'Enable set' : 'Disable set'"
        @click="emit('enable', row.enabled === false)"
      >
        <EyeOff v-if="row.enabled === false" /><Eye v-else />
      </Button>
      <Button
        type="button"
        size="icon-sm"
        variant="ghost"
        :disabled="readOnly || !canDuplicate"
        aria-label="Duplicate set"
        @click="emit('duplicate')"
        ><Copy
      /></Button>
      <Button
        type="button"
        size="icon-sm"
        variant="ghost"
        :disabled="readOnly"
        aria-label="Remove set"
        @click="emit('remove')"
        ><Trash2
      /></Button>
    </div>
    <div v-if="!collapsed" class="border-t p-4">
      <PublishFields
        v-if="set"
        :fields="set.fields"
        :field-path-prefix="fieldPathPrefix"
        :meta-path-prefix="metaPathPrefix"
        :read-only="readOnly"
      />
      <p v-else class="text-sm text-red-600">This set type "{{ row.type }}" no longer exists in the schema.</p>
    </div>
  </div>
</template>
