<script setup lang="ts">
import { router } from '@inertiajs/vue3'
import { onBeforeUnmount, nextTick } from 'vue'
import { SidebarInset, SidebarProvider } from '@/components/ui/sidebar'
import { Toaster } from '@/components/ui/sonner'
import CommandPalette from '@/components/cp/command-palette/CommandPalette.vue'
import ConfirmDialog from '@/components/cp/page/ConfirmDialog.vue'
import ElevationDialog from '@/components/cp/shell/ElevationDialog.vue'
import GlobalHeader from '@/components/cp/shell/GlobalHeader.vue'
import NavSidebar from '@/components/cp/shell/NavSidebar.vue'
import SiteSlot from '@/components/cp/SiteSlot.vue'
import ShortcutsDialog from '@/components/cp/shell/ShortcutsDialog.vue'
import { useCp, useFlashToasts } from '@/lib/cp'

defineOptions({ inheritAttrs: false })
import { injectBreadcrumbs, provideBreadcrumbs } from '@/lib/breadcrumbs'
import { commandPaletteOpen } from '@/lib/commandPalette'
import { usePreference } from '@/lib/preferences'
import { labelForVisit, recordVisit } from '@/lib/recentVisits'
import { shortcutsDialogOpen, useShortcut } from '@/lib/shortcuts'
import { useTheme } from '@/lib/theme'
import 'vue-sonner/style.css'

const cp = useCp()
useFlashToasts(() => cp.value.flash)
useTheme()
provideBreadcrumbs()
const breadcrumbs = injectBreadcrumbs()
useShortcut('?', () => (shortcutsDialogOpen.value = true), { label: 'Show keyboard shortcuts' })
useShortcut('mod+k', () => (commandPaletteOpen.value = true), { label: 'Open command palette' })

const collapsed = usePreference('sidebar_collapsed', false)
const expanded = usePreference('layout_expanded', false)

// nextTick: 'navigate' fires before the new page's setup has set its breadcrumbs.
const stopWatchingNavigation = router.on('navigate', (event) => {
  if (event.detail.page.component.startsWith('cp/errors/') || event.detail.page.component.startsWith('cp/auth/')) return
  nextTick(() =>
    recordVisit(event.detail.page.url, labelForVisit(event.detail.page.url, breadcrumbs.value, cp.value.nav)),
  )
})
onBeforeUnmount(stopWatchingNavigation)
</script>

<template>
  <SidebarProvider class="bg-header" :open="!collapsed" @update:open="(open) => (collapsed = !open)">
    <GlobalHeader />
    <NavSidebar />
    <SidebarInset
      class="mt-14 min-h-[calc(100svh-3.5rem)] min-w-0 bg-body-bg md:rounded-tr-2xl md:peer-data-[state=collapsed]:rounded-tl-2xl"
    >
      <main
        :class="[
          'm-2 flex-1 rounded-2xl bg-content-bg px-4 pb-6 transition-[margin] duration-200 ease-linear sm:px-12 dark:border dark:border-gray-950',
          !collapsed && 'md:ms-0',
        ]"
      >
        <div :class="['w-full min-w-0', expanded ? '' : 'mx-auto max-w-page']"><slot /></div>
      </main>
    </SidebarInset>
    <Toaster rich-colors />
    <ConfirmDialog />
    <ElevationDialog />
    <ShortcutsDialog />
    <CommandPalette />
    <SiteSlot name="Scripts" />
  </SidebarProvider>
</template>
