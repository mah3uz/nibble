<script setup lang="ts">
import { ChevronDown, Heading, Link2, ListTree, Plus, Shapes } from '@lucide/vue'
import { computed } from 'vue'
import { Button } from '@/components/ui/button'
import { DropdownMenu, DropdownMenuContent, DropdownMenuItem, DropdownMenuTrigger } from '@/components/ui/dropdown-menu'
import { useNavEditor } from './context'
import type { NavKind } from './types'

defineProps<{ label: string }>()
const emit = defineEmits<{ add: [kind: NavKind] }>()
const { menu } = useNavEditor()

const kinds = computed(() => [
  { kind: 'link' as const, label: 'Link', icon: Link2 },
  ...(menu.headings ? [{ kind: 'heading', label: 'Heading', icon: Heading }] : []),
  ...(menu.queries?.length ? [{ kind: 'query', label: 'List of pages', icon: ListTree }] : []),
  ...(menu.kinds ?? []).map((kind) => ({ kind: kind.handle, label: kind.display, icon: Shapes })),
])
</script>

<template>
  <div class="inline-flex">
    <Button
      type="button"
      variant="outline"
      size="sm"
      :class="kinds.length > 1 && 'rounded-r-none'"
      @click="emit('add', 'link')"
      ><Plus /> {{ label }}</Button
    >
    <DropdownMenu v-if="kinds.length > 1">
      <DropdownMenuTrigger as-child>
        <Button
          type="button"
          variant="outline"
          size="icon-sm"
          class="rounded-l-none border-l-0"
          :aria-label="`${label}: choose what to add`"
          ><ChevronDown
        /></Button>
      </DropdownMenuTrigger>
      <DropdownMenuContent align="start" class="min-w-40">
        <DropdownMenuItem v-for="option in kinds" :key="option.kind" @select="emit('add', option.kind)"
          ><component :is="option.icon" />{{ option.label }}</DropdownMenuItem
        >
      </DropdownMenuContent>
    </DropdownMenu>
  </div>
</template>
