<script setup lang="ts">
import { router } from '@inertiajs/vue3'
import { ArrowDown, ArrowUp, CornerDownLeft, FilePlus, History, Keyboard, Monitor, SearchIcon, X } from '@lucide/vue'
import {
  DialogContent,
  DialogDescription,
  DialogOverlay,
  DialogPortal,
  DialogRoot,
  DialogTitle,
  ListboxContent,
  ListboxFilter,
  ListboxGroup,
  ListboxGroupLabel,
  ListboxItem,
  ListboxRoot,
} from 'reka-ui'
import { computed, ref, useTemplateRef, watch, type Component } from 'vue'
import StatusIndicator from '@/components/cp/page/StatusIndicator.vue'
import CpIcon from '@/components/cp/icons/CpIcon.vue'
import { NAV_ICONS } from '@/components/cp/shell/icons'
import { useCp, type CpPreferences } from '@/lib/cp'
import { commandPaletteOpen } from '@/lib/commandPalette'
import { usePreference } from '@/lib/preferences'
import { useLayerZIndex } from '@/lib/layers'
import { getRecentVisits, recordVisit, removeRecentVisit } from '@/lib/recentVisits'
import { shortcutsDialogOpen } from '@/lib/shortcuts'
import { fuzzyMatch, type Segment } from './fuzzy'
import type { PaletteGroup } from './types'

type PaletteCommand = {
  id: string
  title: string
  subtitle?: string | null
  icon: Component | string
  status?: 'draft' | 'scheduled' | 'published'
  url?: string
  run: () => void
  removable?: boolean
}

type RenderedCommand = PaletteCommand & { segments: Segment[] }
type RenderedGroup = { label: string; commands: RenderedCommand[] }

const cp = useCp()
const theme = usePreference<CpPreferences['theme']>('theme', 'system')

const zIndex = useLayerZIndex(commandPaletteOpen)
const query = ref('')
const recentVersion = ref(0)
const fetchedGroups = ref<PaletteGroup[]>([])
const loading = ref(false)
let requestId = 0

watch(query, (value) => {
  const term = value.trim()
  if (!term) {
    fetchedGroups.value = []
    loading.value = false
    return
  }

  loading.value = true
  const id = ++requestId
  setTimeout(async () => {
    if (id !== requestId) return
    try {
      const response = await fetch(`/cp/search?q=${encodeURIComponent(term)}`, {
        headers: { Accept: 'application/json' },
      })
      if (id !== requestId) return
      fetchedGroups.value = response.ok ? (await response.json()).groups : []
    } finally {
      if (id === requestId) loading.value = false
    }
  }, 150)
})

watch(commandPaletteOpen, (open) => {
  if (!open) query.value = ''
})

function navigate(url: string, label: string) {
  recordVisit(url, label)
  commandPaletteOpen.value = false
  router.visit(url)
}

function iconFor(handle: string): string {
  return NAV_ICONS[handle] ?? 'magnifying-glass'
}

const searching = computed(() => query.value.trim().length > 0)
const noResults = computed(() => searching.value && !loading.value && groups.value.length === 0)

const searchGroups = computed(() =>
  fetchedGroups.value
    .filter((group) => group.items.length > 0)
    .map((group) => ({
      label: group.label,
      commands: group.items.map<PaletteCommand>((item) => ({
        id: `${group.label}:${item.url}`,
        title: item.title,
        subtitle: item.subtitle,
        icon: iconFor(item.icon),
        status: item.status,
        url: item.url,
        run: () => navigate(item.url, item.title),
      })),
    })),
)

const recentCommands = computed<PaletteCommand[]>(() => {
  void recentVersion.value
  void commandPaletteOpen.value
  return getRecentVisits().map((visit) => ({
    id: `recent:${visit.url}`,
    title: visit.label,
    icon: History,
    url: visit.url,
    removable: true,
    run: () => navigate(visit.url, visit.label),
  }))
})

function removeRecent(url: string) {
  removeRecentVisit(url)
  recentVersion.value++
}

const navCommands = computed<PaletteCommand[]>(() =>
  cp.value.nav.flatMap((section) =>
    section.items.flatMap((item) => [
      {
        id: item.url,
        title: item.title,
        icon: iconFor(item.icon),
        url: item.url,
        run: () => navigate(item.url, item.title),
      },
      ...(item.children ?? []).map((child) => ({
        id: child.url,
        title: `${item.title} › ${child.title}`,
        icon: iconFor(child.icon),
        url: child.url,
        run: () => navigate(child.url, child.title),
      })),
    ]),
  ),
)

const THEME_CYCLE: CpPreferences['theme'][] = ['system', 'light', 'dark']
function toggleTheme() {
  theme.value = THEME_CYCLE[(THEME_CYCLE.indexOf(theme.value) + 1) % THEME_CYCLE.length]
  commandPaletteOpen.value = false
}

const actionCommands = computed<PaletteCommand[]>(() => {
  const commands: PaletteCommand[] = []
  for (const collection of cp.value.collections) {
    if (!collection.create) continue
    const { label, url } = collection.create
    commands.push({
      id: `new-${collection.handle}`,
      title: label,
      icon: FilePlus,
      url,
      run: () => navigate(url, label),
    })
  }
  commands.push({ id: 'toggle-theme', title: 'Toggle theme', icon: Monitor, run: toggleTheme })
  commands.push({
    id: 'shortcuts',
    title: 'Keyboard shortcuts',
    icon: Keyboard,
    run: () => {
      commandPaletteOpen.value = false
      shortcutsDialogOpen.value = true
    },
  })
  return commands
})

function filtered(label: string, commands: PaletteCommand[]): RenderedGroup | null {
  const rendered = commands
    .map((command) => ({ command, match: fuzzyMatch(command.title, query.value) }))
    .filter((entry) => entry.match)
    .sort((a, b) => (searching.value ? b.match!.score - a.match!.score : 0))
    .map(({ command, match }) => ({ ...command, segments: match!.segments }))
  return rendered.length ? { label, commands: rendered } : null
}

const groups = computed<RenderedGroup[]>(() => {
  const content = searchGroups.value.map((group) => ({
    label: group.label,
    commands: group.commands.map((command) => ({
      ...command,
      segments: fuzzyMatch(command.title, query.value)?.segments ?? [{ text: command.title, match: false }],
    })),
  }))
  const local = [
    filtered('Recent', recentCommands.value),
    filtered('Navigation', navCommands.value),
    filtered('Actions', actionCommands.value),
  ].filter((group): group is RenderedGroup => group !== null)
  return [...content, ...local]
})

const visibleCommands = computed<PaletteCommand[]>(() => groups.value.flatMap((group) => group.commands))

const paletteRoot = useTemplateRef<HTMLElement>('paletteRoot')

function moveHighlight(direction: 'ArrowDown' | 'ArrowUp') {
  document.activeElement?.dispatchEvent(new KeyboardEvent('keydown', { key: direction, bubbles: true }))
}

function onKeydownCapture(event: KeyboardEvent) {
  if (event.key === 'Tab') {
    event.preventDefault()
    event.stopPropagation()
    moveHighlight(event.shiftKey ? 'ArrowUp' : 'ArrowDown')
    return
  }
  if (event.ctrlKey && (event.key === 'n' || event.key === 'p')) {
    event.preventDefault()
    event.stopPropagation()
    moveHighlight(event.key === 'n' ? 'ArrowDown' : 'ArrowUp')
    return
  }
  if (event.key !== 'Enter' || !(event.metaKey || event.ctrlKey)) return
  const highlighted = paletteRoot.value?.querySelector<HTMLElement>('[data-highlighted]')
  const url = highlighted?.dataset.url
  if (!url) return
  event.preventDefault()
  event.stopPropagation()
  const command = visibleCommands.value.find((c) => c.url === url)
  recordVisit(url, command?.title ?? url)
  window.open(url, '_blank', 'noopener')
}
</script>

<template>
  <DialogRoot v-model:open="commandPaletteOpen">
    <DialogPortal>
      <DialogOverlay
        :style="{ zIndex }"
        class="fixed inset-0 bg-gray-800/20 backdrop-blur-[2px] duration-200 dark:bg-gray-800/50 data-open:animate-in data-open:fade-in-0 data-closed:animate-out data-closed:fade-out-0"
      />
      <DialogContent
        :style="{ zIndex: zIndex + 1 }"
        class="fixed top-[100px] left-1/2 w-full max-w-[min(90vw,48rem)] -translate-x-1/2 rounded-2xl shadow-[0_8px_5px_-6px_rgba(0,0,0,0.12),_0_3px_8px_0_rgba(0,0,0,0.02),_0_30px_22px_-22px_rgba(39,39,42,0.35)] outline-hidden backdrop-blur-[2px] duration-200 slide-in-from-top-2 dark:shadow-[0_5px_20px_rgba(0,0,0,.5)] data-open:animate-in data-open:fade-in-0 data-open:zoom-in-95 data-closed:animate-out data-closed:fade-out-0 data-closed:zoom-out-95"
      >
        <DialogTitle class="sr-only">Command palette</DialogTitle>
        <DialogDescription class="sr-only">Search for content, navigate, and run actions.</DialogDescription>
        <div ref="paletteRoot" @keydown.capture="onKeydownCapture">
          <ListboxRoot
            highlight-on-hover
            class="relative rounded-xl border-b border-gray-200/80 bg-white shadow-[0_1px_16px_-2px_rgba(63,63,71,0.2)] dark:border-gray-950 dark:bg-gray-800 dark:shadow-[0_10px_15px_rgba(0,0,0,.5)] dark:inset-shadow-2xs dark:inset-shadow-white/10"
          >
            <header class="flex h-14 items-center gap-2 border-b border-gray-200/80 px-5.5 dark:border-gray-950">
              <SearchIcon class="size-5 shrink-0 text-gray-400" />
              <ListboxFilter
                v-model="query"
                auto-focus
                placeholder="Search or jump to..."
                class="flex w-full bg-transparent py-4 text-lg antialiased outline-none placeholder:text-gray-500!"
              />
            </header>
            <ListboxContent
              class="max-h-[360px] min-h-[360px] divide-y divide-gray-200/80 overflow-y-auto dark:divide-gray-950"
            >
              <div v-if="noResults" class="px-3 py-2 opacity-50">
                <div
                  class="flex items-center gap-2 rounded-lg px-2 py-1.5 text-sm text-gray-700 antialiased dark:text-gray-300"
                >
                  <div class="flex size-6 items-center justify-center p-1 text-gray-500">
                    <SearchIcon class="size-4" />
                  </div>
                  No results found!
                </div>
              </div>
              <div v-else-if="loading && !groups.length" class="px-3 py-2">
                <div class="h-9 w-full animate-pulse rounded-lg bg-gray-100 dark:bg-gray-900" />
              </div>
              <ListboxGroup v-for="group in groups" :key="group.label" class="space-y-1 px-3 py-2">
                <ListboxGroupLabel
                  v-if="group.label !== 'Actions'"
                  class="flex items-center gap-2 px-3 py-1 text-xs tracking-tight text-gray-600 dark:text-gray-400"
                  >{{ group.label }}</ListboxGroupLabel
                >
                <ListboxItem
                  v-for="command in group.commands"
                  :key="command.id"
                  :value="command.id"
                  :data-url="command.url"
                  class="flex cursor-pointer items-center gap-2 rounded-lg px-2 py-1.5 text-sm text-gray-700 antialiased outline-hidden data-highlighted:bg-gray-200/70 dark:text-gray-300 dark:data-highlighted:bg-gray-900/70"
                  @select="command.run"
                >
                  <div class="flex size-6 shrink-0 items-center justify-center p-1 text-gray-500">
                    <CpIcon v-if="typeof command.icon === 'string'" :name="command.icon" class="size-4" />
                    <component :is="command.icon" v-else class="size-4" />
                  </div>
                  <div class="flex min-w-0 flex-1 flex-col">
                    <span class="truncate"
                      ><template v-for="(segment, index) in command.segments" :key="index"
                        ><span
                          v-if="segment.match"
                          class="text-blue-600 underline decoration-blue-200 underline-offset-4 dark:text-blue-400 dark:decoration-blue-600/45"
                          >{{ segment.text }}</span
                        ><template v-else>{{ segment.text }}</template></template
                      ></span
                    >
                    <span v-if="command.subtitle" class="truncate text-xs text-gray-500">{{ command.subtitle }}</span>
                  </div>
                  <StatusIndicator v-if="command.status" :status="command.status" class="shrink-0" />
                  <button
                    v-if="command.removable && command.url"
                    type="button"
                    class="shrink-0 opacity-30 hover:opacity-70"
                    :aria-label="`Remove ${command.title} from recent`"
                    @pointerdown.prevent.stop
                    @click.prevent.stop="removeRecent(command.url)"
                  >
                    <X class="size-4" />
                  </button>
                </ListboxItem>
              </ListboxGroup>
            </ListboxContent>
            <footer
              class="flex items-center gap-4 rounded-b-xl border-t border-gray-200/80 bg-gray-50 px-6 py-3 dark:border-gray-950 dark:bg-gray-800/20"
            >
              <div class="flex items-center gap-1.5">
                <ArrowUp class="size-4 rounded-sm border border-gray-300 p-0.5 text-gray-500" />
                <ArrowDown class="size-4 rounded-sm border border-gray-300 p-0.5 text-gray-500" />
                <span class="text-sm text-gray-600 dark:text-gray-500">Navigate</span>
              </div>
              <div class="flex items-center gap-1.5">
                <CornerDownLeft class="size-4 rounded-sm border border-gray-300 p-0.5 text-gray-500" />
                <span class="text-sm text-gray-600 dark:text-gray-500">Select</span>
              </div>
            </footer>
          </ListboxRoot>
        </div>
      </DialogContent>
    </DialogPortal>
  </DialogRoot>
</template>
