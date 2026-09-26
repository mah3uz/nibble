<script setup lang="ts">
import { Link } from '@inertiajs/vue3'
import { ChevronRight } from '@lucide/vue'
import { ref } from 'vue'
import StatusCell from '@/components/cp/listing/cells/StatusCell.vue'

type TreeNode = {
  segment: string
  path: string
  page: { id: number; title: string; status: string; edit_url: string } | null
  children: TreeNode[]
}
defineProps<{ node: TreeNode }>()
const expanded = ref(true)
</script>

<template>
  <li>
    <div class="flex items-center gap-2 py-1.5">
      <button
        v-if="node.children.length"
        type="button"
        class="shrink-0 text-muted-foreground"
        :aria-label="expanded ? `Collapse ${node.segment}` : `Expand ${node.segment}`"
        @click="expanded = !expanded"
      >
        <ChevronRight class="size-4 transition-transform" :class="expanded && 'rotate-90'" />
      </button>
      <span v-else class="w-4 shrink-0" />
      <Link v-if="node.page" :href="node.page.edit_url" class="font-medium hover:underline">{{ node.page.title }}</Link>
      <span v-else class="text-muted-foreground italic">(no page)</span>
      <code class="text-xs text-muted-foreground">{{ node.path }}</code>
      <StatusCell v-if="node.page" :value="node.page.status" />
    </div>
    <ul v-if="expanded && node.children.length" class="ml-2 border-l border-border pl-4">
      <PageTreeItem v-for="child in node.children" :key="child.path" :node="child" />
    </ul>
  </li>
</template>
