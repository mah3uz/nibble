<script setup lang="ts">
import { Link, router, usePage } from '@inertiajs/vue3'
import { computed, ref } from 'vue'
import CpIcon from '@/components/cp/icons/CpIcon.vue'
import NavTree from '@/components/cp/navigation/NavTree.vue'
import type { NavEntry, NavTreeItem } from '@/components/cp/navigation/types'
import PageHeader from '@/components/cp/page/PageHeader.vue'
import { Button } from '@/components/ui/button'
import { skipNextGuard, useDirtyGuard } from '@/lib/dirty-guard'

const props = defineProps<{
  menu: { handle: string; title: string; max_depth: number; locale: string }
  tree: NavTreeItem[]
  records: NavEntry[]
  source?: { folder: string; links: { title: string; url: string; depth: number }[] } | null
}>()

const page = usePage<{ errors: Record<string, string> }>()
const items = ref<NavTreeItem[]>(props.tree)
const processing = ref(false)
const baseline = ref(JSON.stringify(props.tree))

const dirty = computed(() => JSON.stringify(items.value) !== baseline.value)
const error = computed(() => page.props.errors?.tree)
useDirtyGuard(() => dirty.value)

function save() {
  processing.value = true
  skipNextGuard()
  router.patch(
    `/cp/navigation/${props.menu.handle}`,
    { tree: items.value },
    {
      preserveScroll: true,
      onSuccess: () => (baseline.value = JSON.stringify(items.value)),
      onFinish: () => (processing.value = false),
    },
  )
}
</script>

<template>
  <div class="mx-auto max-w-5xl">
    <Link
      href="/cp/navigation"
      class="relative z-10 -mb-6 flex w-fit items-center gap-1 pt-6 text-sm text-gray-600 hover:text-gray-900 dark:text-gray-400 dark:hover:text-white"
    >
      <CpIcon name="chevron-left" class="size-4" />Navigation
    </Link>
    <PageHeader
      :title="menu.title"
      icon="navigation"
      :breadcrumbs="[{ label: 'Navigation', url: '/cp/navigation' }, { label: menu.title }]"
    >
      <template v-if="!source" #actions><Button :disabled="processing" @click="save">Save</Button></template>
    </PageHeader>
    <template v-if="source">
      <p
        class="mb-4 rounded-lg border border-gray-200 bg-gray-50 px-3.5 py-2.5 text-sm text-gray-600 dark:border-gray-700 dark:bg-gray-850 dark:text-gray-400"
      >
        Built from the folders in <code class="font-mono text-[0.8125rem]">{{ source.folder }}</code
        >. Change the files there and deploy.
      </p>
      <ul class="rounded-lg border border-gray-200 dark:border-gray-700">
        <li
          v-for="link in source.links"
          :key="link.url"
          class="flex items-center justify-between gap-4 border-b border-gray-200 py-2.5 pr-3.5 text-sm last:border-b-0 dark:border-gray-700"
          :style="{ paddingLeft: `${0.875 + link.depth * 1.5}rem` }"
        >
          <span>{{ link.title }}</span>
          <code class="font-mono text-xs text-gray-500">{{ link.url }}</code>
        </li>
      </ul>
    </template>
    <template v-else>
      <p v-if="error" class="mb-4 text-sm text-destructive">{{ error }}</p>
      <NavTree v-model="items" :depth="0" :max-depth="menu.max_depth" :entries="records" />
    </template>
  </div>
</template>
