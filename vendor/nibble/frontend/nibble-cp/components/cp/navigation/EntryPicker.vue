<script setup lang="ts">
import { Check, ChevronsUpDown } from '@lucide/vue'
import { computed, ref } from 'vue'
import { Button } from '@/components/ui/button'
import { Command, CommandEmpty, CommandGroup, CommandInput, CommandItem, CommandList } from '@/components/ui/command'
import { Popover, PopoverContent, PopoverTrigger } from '@/components/ui/popover'
import type { NavEntry } from './types'

const props = defineProps<{ entries: NavEntry[]; disabled?: boolean }>()
const selectedId = defineModel<number | null>({ default: null })

const open = ref(false)
const selected = computed(() => props.entries.find((entry) => entry.id === selectedId.value) ?? null)

function pick(entry: NavEntry) {
  selectedId.value = entry.id
  open.value = false
}
</script>

<template>
  <Popover v-model:open="open">
    <PopoverTrigger as-child>
      <Button
        type="button"
        variant="outline"
        role="combobox"
        :aria-expanded="open"
        :disabled="disabled"
        class="w-full justify-between font-normal"
      >
        <span class="truncate">{{ selected ? selected.title : 'Choose…' }}</span>
        <ChevronsUpDown class="shrink-0 opacity-50" />
      </Button>
    </PopoverTrigger>
    <PopoverContent class="w-80 p-0">
      <Command>
        <CommandInput placeholder="Search…" />
        <CommandList>
          <CommandEmpty>No results.</CommandEmpty>
          <CommandGroup>
            <CommandItem
              v-for="entry in entries"
              :key="entry.id"
              :value="`${entry.title} ${entry.path}`"
              @select="pick(entry)"
            >
              <Check :class="selectedId === entry.id ? 'opacity-100' : 'opacity-0'" />
              <div class="flex min-w-0 flex-1 flex-col">
                <span class="truncate">{{ entry.title }}</span>
                <span class="truncate text-xs text-muted-foreground"
                  >{{ entry.path }}<template v-if="!entry.live"> · not live</template></span
                >
              </div>
            </CommandItem>
          </CommandGroup>
        </CommandList>
      </Command>
    </PopoverContent>
  </Popover>
</template>
