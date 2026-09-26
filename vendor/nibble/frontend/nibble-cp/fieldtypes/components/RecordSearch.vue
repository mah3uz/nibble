<script setup lang="ts">
import { useDebounceFn } from '@vueuse/core'
import { Check, ChevronDown } from '@lucide/vue'
import { ref, watch } from 'vue'
import { Command, CommandEmpty, CommandGroup, CommandInput, CommandItem, CommandList } from '@/components/ui/command'
import { Popover, PopoverContent, PopoverTrigger } from '@/components/ui/popover'
import { searchRelationships, type ItemSummary } from '../../lib/relationships'

const props = defineProps<{
  type: string
  scope?: Record<string, unknown>
  selectedIds: string[]
  label: string
  disabled?: boolean
  id?: string
}>()
const emit = defineEmits<{ pick: [item: ItemSummary] }>()

const open = ref(false)
const query = ref('')
const results = ref<ItemSummary[]>([])
const loading = ref(false)
const failed = ref<string | null>(null)

const run = useDebounceFn(async () => {
  loading.value = true
  failed.value = null
  try {
    results.value = await searchRelationships(props.type, { query: query.value, scope: props.scope })
  } catch (error) {
    failed.value = (error as Error).message
    results.value = []
  } finally {
    loading.value = false
  }
}, 200)

watch(open, (isOpen) => isOpen && run())
watch(query, () => open.value && run())
</script>

<template>
  <Popover v-model:open="open">
    <PopoverTrigger as-child>
      <button
        :id="id"
        type="button"
        role="combobox"
        :aria-expanded="open"
        :aria-label="label"
        :disabled="disabled"
        class="flex h-10 w-full cursor-pointer items-center justify-between rounded-lg border border-gray-300 bg-linear-to-b from-white to-gray-50 px-4 text-base text-gray-900 antialiased shadow-ui-sm outline-none focus-visible:focus-outline disabled:cursor-not-allowed disabled:border-dashed disabled:opacity-50 dark:border-gray-700 dark:from-gray-850 dark:to-gray-900 dark:text-gray-300 dark:shadow-ui-md"
      >
        <span class="truncate text-gray-500 dark:text-gray-400">{{ label }}</span>
        <ChevronDown class="ms-1.5 -me-1 size-4 shrink-0 text-gray-400 dark:text-white/40" />
      </button>
    </PopoverTrigger>
    <PopoverContent class="w-(--reka-popover-trigger-width) p-0">
      <Command v-model:search-term="query" :filter-function="(list: unknown[]) => list">
        <CommandInput placeholder="Search…" />
        <CommandList>
          <CommandEmpty>{{ loading ? 'Searching…' : (failed ?? 'No results.') }}</CommandEmpty>
          <CommandGroup>
            <CommandItem
              v-for="item in results"
              :key="item.id"
              :value="item.id"
              :class="selectedIds.includes(item.id) && 'bg-blue-50 text-blue-600! dark:bg-blue-600 dark:text-blue-50!'"
              @select="emit('pick', item)"
            >
              <img v-if="item.thumbnail" :src="item.thumbnail" alt="" class="size-8 rounded object-cover" />
              <span class="min-w-0 flex-1 truncate">{{ item.title }}</span>
              <Check v-if="selectedIds.includes(item.id)" class="ms-auto" />
            </CommandItem>
          </CommandGroup>
        </CommandList>
      </Command>
    </PopoverContent>
  </Popover>
</template>
