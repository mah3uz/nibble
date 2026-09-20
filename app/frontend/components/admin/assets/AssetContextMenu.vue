<script setup lang="ts">
import {
  ContextMenuContent,
  ContextMenuItem,
  ContextMenuPortal,
  ContextMenuRoot,
  ContextMenuSeparator,
  ContextMenuTrigger,
} from 'reka-ui'
import { computed } from 'vue'
import AdminIcon from '@/components/admin/icons/AdminIcon.vue'
import type { Abilities } from './api'
import { assetMenuItems, type AssetMenuAction } from './assetMenu'

const props = defineProps<{ can: Abilities }>()
const emit = defineEmits<{ run: [action: AssetMenuAction] }>()
const items = computed(() => assetMenuItems(props.can))
</script>

<template>
  <ContextMenuRoot>
    <ContextMenuTrigger as-child><slot /></ContextMenuTrigger>
    <ContextMenuPortal>
      <ContextMenuContent
        class="z-1000 min-w-60 rounded-xl border border-gray-200 bg-white p-1.5 text-gray-900 shadow-lg duration-100 dark:border-black dark:bg-gray-850 dark:text-gray-300 data-open:animate-in data-open:fade-in-0 data-closed:animate-out data-closed:fade-out-0"
      >
        <template v-for="item in items" :key="item.action">
          <ContextMenuSeparator v-if="item.separated" class="-mx-1.5 my-1.5 h-px bg-gray-200 dark:bg-gray-700" />
          <ContextMenuItem
            :data-variant="item.destructive ? 'destructive' : 'default'"
            class="relative flex cursor-pointer items-center gap-2 rounded-lg px-2 py-1.5 text-sm text-gray-700 antialiased outline-hidden select-none hover:bg-gray-100 focus:bg-gray-100 data-[variant=destructive]:text-red-600 dark:text-gray-300 dark:hover:bg-gray-800 dark:focus:bg-gray-800 dark:data-[variant=destructive]:text-red-500 [&_svg]:text-gray-500 data-[variant=destructive]:[&_svg]:text-red-500!"
            @select="emit('run', item.action)"
          >
            <AdminIcon :name="item.icon" class="size-4" /> {{ item.label }}
          </ContextMenuItem>
        </template>
      </ContextMenuContent>
    </ContextMenuPortal>
  </ContextMenuRoot>
</template>
