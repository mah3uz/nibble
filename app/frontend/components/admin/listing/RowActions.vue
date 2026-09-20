<script setup lang="ts">
import { MoreHorizontal } from '@lucide/vue'
import { computed } from 'vue'
import { Button } from '@/components/ui/button'
import { DropdownMenu, DropdownMenuContent, DropdownMenuItem, DropdownMenuTrigger } from '@/components/ui/dropdown-menu'
import type { ListingAction } from './types'

const props = defineProps<{ actions: ListingAction[]; handles: string[] }>()
const emit = defineEmits<{ run: [action: ListingAction] }>()
const available = computed(() => props.actions.filter((a) => props.handles.includes(a.handle)))
</script>

<template>
  <DropdownMenu v-if="available.length">
    <DropdownMenuTrigger as-child>
      <Button variant="ghost" size="icon-sm" aria-label="Actions"><MoreHorizontal /></Button>
    </DropdownMenuTrigger>
    <DropdownMenuContent align="end">
      <DropdownMenuItem
        v-for="action in available"
        :key="action.handle"
        :variant="action.dangerous ? 'destructive' : 'default'"
        @click="emit('run', action)"
        >{{ action.label }}</DropdownMenuItem
      >
    </DropdownMenuContent>
  </DropdownMenu>
</template>
