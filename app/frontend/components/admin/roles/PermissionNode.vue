<script setup lang="ts">
import { Checkbox } from '@/components/ui/checkbox'

export type PermissionTreeNode = {
  value: string
  title: string
  description: string | null
  children: PermissionTreeNode[]
}

defineProps<{
  node: PermissionTreeNode
  checked: (value: string) => boolean
  locked: (value: string) => boolean
}>()

const emit = defineEmits<{ toggle: [node: PermissionTreeNode, on: boolean] }>()
</script>

<template>
  <div class="space-y-3">
    <label class="flex items-start gap-2.5">
      <Checkbox
        class="mt-0.5"
        :model-value="checked(node.value)"
        :disabled="locked(node.value)"
        @update:model-value="(on) => emit('toggle', node, !!on)"
      />
      <span>
        <span class="text-sm">{{ node.title }}</span>
        <span v-if="node.description" class="block text-sm text-gray-500 dark:text-gray-400">
          {{ node.description }}
        </span>
      </span>
    </label>
    <div v-if="node.children.length" class="ms-6 space-y-3">
      <PermissionNode
        v-for="child in node.children"
        :key="child.value"
        :node="child"
        :checked="checked"
        :locked="locked"
        @toggle="(target, on) => emit('toggle', target, on)"
      />
    </div>
  </div>
</template>
