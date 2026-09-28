<script setup lang="ts">
import { Plus } from '@lucide/vue'
import { computed, ref } from 'vue'
import CpIcon from '@/components/cp/icons/CpIcon.vue'
import { Button } from '@/components/ui/button'
import { Command, CommandEmpty, CommandGroup, CommandInput, CommandItem, CommandList } from '@/components/ui/command'
import { Popover, PopoverContent, PopoverTrigger } from '@/components/ui/popover'
import type { PublishSetGroup } from '../types'

const SEARCH_FROM = 9

const props = defineProps<{ groups: PublishSetGroup[]; disabled?: boolean; label?: string; iconOnly?: boolean }>()
const emit = defineEmits<{ pick: [handle: string] }>()

const open = ref(false)
const sets = computed(() => props.groups.flatMap((group) => group.sets))
const only = computed(() => (sets.value.length === 1 ? sets.value[0] : null))

function pick(handle: string) {
  open.value = false
  emit('pick', handle)
}
</script>

<template>
  <Button
    v-if="only"
    type="button"
    variant="outline"
    :size="iconOnly ? 'icon-sm' : 'sm'"
    :disabled="disabled"
    :aria-label="iconOnly ? (label ?? `Add ${only.display}`) : undefined"
    @click="pick(only.handle)"
  >
    <Plus /><template v-if="!iconOnly">{{ label || `Add ${only.display}` }}</template>
  </Button>
  <Popover v-else v-model:open="open">
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
    <PopoverContent align="start" class="w-64 p-0">
      <Command>
        <CommandInput v-if="sets.length >= SEARCH_FROM" placeholder="Search…" />
        <CommandList class="max-h-96">
          <CommandEmpty>Nothing matches.</CommandEmpty>
          <CommandGroup v-for="group in groups" :key="group.handle" :heading="group.display ?? undefined">
            <CommandItem v-for="set in group.sets" :key="set.handle" :value="set.display" @select="pick(set.handle)">
              <CpIcon v-if="set.icon" :name="set.icon" class="size-4 text-muted-foreground" />
              <span class="min-w-0 flex-1">
                <span class="block truncate">{{ set.display }}</span>
                <span v-if="set.instructions" class="block truncate text-xs text-muted-foreground">{{
                  set.instructions
                }}</span>
              </span>
            </CommandItem>
          </CommandGroup>
        </CommandList>
      </Command>
    </PopoverContent>
  </Popover>
</template>
