<script setup lang="ts">
import { computed } from 'vue'
import AdminIcon from '@/components/admin/icons/AdminIcon.vue'
import { Button } from '@/components/ui/button'
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from '@/components/ui/dropdown-menu'
import type { Abilities } from './api'
import { assetMenuItems, type AssetMenuAction } from './assetMenu'

const props = defineProps<{ can: Abilities; label: string }>()
const emit = defineEmits<{ run: [action: AssetMenuAction] }>()
const items = computed(() => assetMenuItems(props.can))
</script>

<template>
  <DropdownMenu>
    <DropdownMenuTrigger as-child>
      <Button variant="ghost" size="icon-sm" :aria-label="`Actions for ${label}`" @click.stop
        ><AdminIcon name="dots" class="size-4"
      /></Button>
    </DropdownMenuTrigger>
    <DropdownMenuContent align="start" side="left" class="min-w-60">
      <template v-for="item in items" :key="item.action">
        <DropdownMenuSeparator v-if="item.separated" />
        <DropdownMenuItem :variant="item.destructive ? 'destructive' : 'default'" @click="emit('run', item.action)">
          <AdminIcon :name="item.icon" class="size-4" /> {{ item.label }}
        </DropdownMenuItem>
      </template>
    </DropdownMenuContent>
  </DropdownMenu>
</template>
