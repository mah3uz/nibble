<script setup lang="ts">
import { Link, router } from '@inertiajs/vue3'
import { useSortable } from '@vueuse/integrations/useSortable'
import { ref, useTemplateRef } from 'vue'
import AdminIcon from '@/components/admin/icons/AdminIcon.vue'

export type TreeNode = {
  id: number
  title: string | null
  status: string
  uri: string | null
  parent_id: number | null
  edit_url: string
  children: TreeNode[]
}

const props = defineProps<{ nodes: TreeNode[]; collection: string; depth?: number }>()
const list = ref<TreeNode[]>(props.nodes)
const DOT: Record<string, string> = {
  published: 'bg-green-400',
  scheduled: 'bg-amber-400',
  in_review: 'bg-sky-400',
  approved: 'bg-sky-400',
}
const container = useTemplateRef<HTMLElement>('container')

useSortable(container, list, {
  handle: '[data-drag]',
  animation: 150,
  forceFallback: true,
  fallbackOnBody: true,
  dragClass: 'sortable-drag-clone',
  ghostClass: 'sortable-ghost-placeholder',
  onUpdate: () => {
    router.post(
      `/admin/collections/${props.collection}/entries/reorder`,
      {
        order: list.value.map((node) => ({ id: node.id, parent_id: node.parent_id })),
      },
      { preserveScroll: true },
    )
  },
})
</script>

<template>
  <ul ref="container" class="space-y-1" :class="depth ? 'ms-6 mt-1' : ''" role="list">
    <li v-for="node in list" :key="node.id">
      <div
        class="flex rounded-xl bg-white text-xs shadow-sm ring-1 ring-black/2 dark:bg-gray-800 dark:shadow-none dark:ring-0"
      >
        <button
          type="button"
          data-drag
          class="flex w-6 shrink-0 cursor-grab items-center justify-center rounded-s-xl text-gray-400 hover:text-gray-600 dark:text-gray-500 dark:hover:text-gray-300"
          :aria-label="`Reorder ${node.title}`"
        >
          <AdminIcon name="drag-dots" class="h-4.25 w-1.75" />
        </button>
        <div class="flex min-w-0 flex-1 items-center gap-2 px-1.5 sm:gap-3">
          <div class="flex min-w-0 grow items-center gap-2 py-3 sm:gap-3">
            <span :class="['size-2 shrink-0 rounded-full', DOT[node.status] ?? 'bg-gray-300 dark:bg-gray-600']" />
            <span class="sr-only">{{ node.status }}</span>
            <Link
              :href="node.edit_url"
              class="truncate text-sm font-medium text-gray-900 hover:underline dark:text-white"
              >{{ node.title ?? 'Untitled' }}</Link
            >
          </div>
          <span
            v-if="node.uri"
            class="me-2 hidden truncate rounded-[0.1875rem] border border-gray-300 bg-gray-50 px-1.25 font-mono text-2xs text-gray-700 sm:inline dark:border-gray-700 dark:bg-gray-800 dark:text-gray-100"
            >{{ node.uri }}</span
          >
        </div>
      </div>
      <EntryTree
        v-if="node.children.length"
        :nodes="node.children"
        :collection="collection"
        :depth="(depth ?? 0) + 1"
      />
    </li>
  </ul>
</template>
