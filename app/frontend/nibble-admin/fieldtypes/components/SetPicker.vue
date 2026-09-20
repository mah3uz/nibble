<script setup lang="ts">
import { Plus } from '@lucide/vue'
import { Button } from '@/components/ui/button'
import { Command, CommandEmpty, CommandGroup, CommandInput, CommandItem, CommandList } from '@/components/ui/command'
import { Popover, PopoverContent, PopoverTrigger } from '@/components/ui/popover'
import type { PublishSetGroup } from '../types'

defineProps<{ groups: PublishSetGroup[]; disabled?: boolean; label?: string; iconOnly?: boolean }>()
const emit = defineEmits<{ pick: [handle: string] }>()
</script>

<template>
  <Popover>
    <PopoverTrigger as-child>
      <Button
        type="button"
        variant="outline"
        :size="iconOnly ? 'icon-sm' : 'sm'"
        :disabled="disabled"
        :aria-label="iconOnly ? (label ?? 'Add set') : undefined"
      >
        <Plus /><template v-if="!iconOnly">{{ label || 'Add set' }}</template>
      </Button>
    </PopoverTrigger>
    <PopoverContent class="w-72 p-0">
      <Command>
        <CommandInput placeholder="Search…" />
        <CommandList>
          <CommandEmpty>No sets.</CommandEmpty>
          <CommandGroup v-for="group in groups" :key="group.handle" :heading="group.display ?? undefined">
            <CommandItem
              v-for="set in group.sets"
              :key="set.handle"
              :value="set.display"
              @select="emit('pick', set.handle)"
            >
              <div class="flex min-w-0 flex-1 flex-col">
                <span class="truncate">{{ set.display }}</span>
                <span v-if="set.instructions" class="truncate text-xs text-muted-foreground">{{
                  set.instructions
                }}</span>
              </div>
            </CommandItem>
          </CommandGroup>
        </CommandList>
      </Command>
    </PopoverContent>
  </Popover>
</template>
