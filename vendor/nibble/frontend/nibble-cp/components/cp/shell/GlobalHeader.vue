<script setup lang="ts">
import { Link } from '@inertiajs/vue3'
import logo from '@/assets/nibble.svg?url'
import CpIcon from '@/components/cp/icons/CpIcon.vue'
import SiteSlot from '@/components/cp/SiteSlot.vue'
import { useSidebar } from '@/components/ui/sidebar'
import { useCp } from '@/lib/cp'
import { injectBreadcrumbs } from '@/lib/breadcrumbs'
import { commandPaletteOpen } from '@/lib/commandPalette'
import { usePreference } from '@/lib/preferences'
import { formatCombo } from '@/lib/shortcuts'
import PageBreadcrumbs from './PageBreadcrumbs.vue'
import NotificationBell from './NotificationBell.vue'
import UserMenu from './UserMenu.vue'

const cp = useCp()
const breadcrumbs = injectBreadcrumbs()
const expanded = usePreference('layout_expanded', false)
const { toggleSidebar } = useSidebar()
</script>

<template>
  <header class="fixed inset-x-0 top-0 z-30 flex h-14 items-center gap-2 bg-header px-2 text-header-foreground lg:px-4">
    <div class="flex min-w-0 flex-1 items-center gap-3.5 text-[0.8125rem] text-white/85">
      <div class="flex shrink-0 items-center gap-1.5 sm:gap-2.5">
        <button
          type="button"
          class="flex size-6 cursor-pointer items-center justify-center rounded-xs opacity-75 hover:opacity-100 max-sm:ps-1"
          aria-label="Toggle navigation"
          @click="toggleSidebar"
        >
          <CpIcon name="hamburger" class="size-3.5 sm:size-3.25" />
        </button>
        <Link href="/cp" class="flex items-center gap-1.5 rounded-xs whitespace-nowrap text-white/85 hover:text-white">
          <SiteSlot name="Logo"><img :src="logo" alt="" class="size-7" /></SiteSlot>
          <span>Nibble</span>
        </Link>
      </div>
      <PageBreadcrumbs :trail="breadcrumbs" />
    </div>
    <div class="flex shrink-0 items-center justify-end gap-1 sm:gap-3 md:gap-2">
      <button
        type="button"
        class="group flex h-8 w-8 cursor-pointer items-center justify-center gap-x-1.5 rounded-xl bg-black/40 text-xs text-white/60 ring-1 ring-white/10 hover:bg-black/45 hover:text-white/70 sm:w-32 sm:justify-start sm:px-2"
        @click="commandPaletteOpen = true"
      >
        <CpIcon name="magnifying-glass" class="size-4 text-white/50 group-hover:text-white/70" />
        <span class="sr-only sm:not-sr-only">Search</span>
        <kbd
          class="ml-auto hidden rounded-md bg-white/5 px-1.25 py-px font-sans text-[0.625rem]/4 font-medium text-white/60 ring-1 ring-white/7.5 ring-inset group-hover:text-white/70 md:block"
          >{{ formatCombo('mod+k') }}</kbd
        >
      </button>
      <button
        type="button"
        class="hidden size-8 cursor-pointer items-center justify-center rounded-lg text-white/85 hover:bg-white/15 sm:-me-2 sm:inline-flex"
        aria-label="Expand layout"
        title="Expand layout"
        :aria-pressed="expanded"
        @click="expanded = !expanded"
      >
        <CpIcon name="layout-expand" :class="['size-4', expanded && 'text-white']" />
      </button>
      <a
        :href="cp.site_url"
        target="_blank"
        rel="noopener"
        aria-label="View site"
        title="View site"
        class="inline-flex size-8 items-center justify-center rounded-lg text-white/85 hover:bg-white/15 sm:-me-2"
      >
        <CpIcon name="view-site" class="size-4" />
      </a>
      <NotificationBell />
      <UserMenu />
    </div>
  </header>
</template>
