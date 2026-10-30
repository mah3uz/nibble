<script setup lang="ts">
import type { RequestPayload } from '@inertiajs/core'
import { Link, router, usePage } from '@inertiajs/vue3'
import { computed, nextTick, ref } from 'vue'
import CpIcon from '@/components/cp/icons/CpIcon.vue'
import { provideNavEditor } from '@/components/cp/navigation/context'
import NavTree from '@/components/cp/navigation/NavTree.vue'
import { errorsByItem, itemAt, move, pathOf } from '@/components/cp/navigation/tree'
import type { NavAsset, NavEntry, NavItemErrors, NavMenu, NavTreeItem } from '@/components/cp/navigation/types'
import PageHeader from '@/components/cp/page/PageHeader.vue'
import { Button } from '@/components/ui/button'
import { skipNextGuard, useDirtyGuard } from '@/lib/dirty-guard'
import { registerCoreFieldtypes } from '@nibble-cp/fieldtypes/core'

const props = defineProps<{
  menu: NavMenu
  tree: NavTreeItem[]
  records: NavEntry[]
  query_records?: NavEntry[]
  assets?: NavAsset[]
  source?: { folder: string; links: { title: string; url: string; depth: number }[] } | null
}>()

registerCoreFieldtypes()

const page = usePage<{ errors: Record<string, string> }>()
const items = ref<NavTreeItem[]>(props.tree)
const processing = ref(false)
const baseline = ref(JSON.stringify(props.tree))
const assets = ref<Record<string, NavAsset>>(Object.fromEntries((props.assets ?? []).map((a) => [a.id, a])))
const itemErrors = ref<Record<string, NavItemErrors>>({})
const collapsed = ref(new Set<string>())
const announcement = ref('')

const dirty = computed(() => JSON.stringify(items.value) !== baseline.value)
const error = computed(() => page.props.errors?.tree)
useDirtyGuard(() => dirty.value)

function announce(text: string) {
  announcement.value = ''
  nextTick(() => (announcement.value = text))
}

function position(id: string): string {
  const path = pathOf(items.value, id)!
  const parent = path.length > 1 ? itemAt(items.value, path.slice(0, -1)) : undefined
  const count = parent ? parent.children.length : items.value.length
  return `${path.at(-1)! + 1} of ${count}, ${parent ? `under “${parent.title}”` : 'at the top level'}.`
}

function change(next: NavTreeItem[] | null, id: string, done: string) {
  const title = itemAt(items.value, pathOf(items.value, id) ?? [])?.title
  if (!next) return announce(`“${title}” can't move that way.`)
  items.value = next
  announce(`${done} Now ${position(id)}`)
  // A moved item is drawn afresh in its new list, so its handle gets focus back once that is on screen.
  nextTick(() => requestAnimationFrame(() => document.querySelector<HTMLElement>(`[data-move="${id}"]`)?.focus()))
}

provideNavEditor({
  menu: props.menu,
  entries: props.records,
  queryRecords: props.query_records ?? [],
  tree: items,
  assets,
  errors: itemErrors,
  collapsed,
  change,
  moveTo: (from, toParent, index) => {
    const item = itemAt(items.value, from)
    if (item)
      change(
        move(items.value, from, toParent, index, props.menu.max_depth, props.menu.kinds),
        item.id,
        `Moved “${item.title}”.`,
      )
  },
})

function showErrors(errors: Record<string, string | string[]>) {
  itemErrors.value = errorsByItem(items.value, errors)
  const open = new Set(collapsed.value)
  for (const id of Object.keys(itemErrors.value)) {
    const path = pathOf(items.value, id) ?? []
    for (let depth = 1; depth < path.length; depth++) open.delete(itemAt(items.value, path.slice(0, depth))!.id)
  }
  collapsed.value = open
}

function save() {
  processing.value = true
  skipNextGuard()
  router.patch(`/cp/navigation/${props.menu.handle}`, { tree: items.value } as unknown as RequestPayload, {
    preserveScroll: true,
    onSuccess: () => {
      baseline.value = JSON.stringify(items.value)
      itemErrors.value = {}
    },
    onError: showErrors,
    onFinish: () => (processing.value = false),
  })
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
        <span :title="source.folder"
          >This menu is built from the site's files, so it can't be edited here. Ask a developer to change it.</span
        >
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
      <NavTree :path="[]" />
      <p class="sr-only" aria-live="polite">{{ announcement }}</p>
    </template>
  </div>
</template>
