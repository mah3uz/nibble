<script setup lang="ts">
import { Link, router } from '@inertiajs/vue3'
import { Keyboard, LogOut, Monitor, Moon, Sun, UserCircle } from '@lucide/vue'
import { computed } from 'vue'
import { DropdownMenu, DropdownMenuContent, DropdownMenuItem, DropdownMenuTrigger } from '@/components/ui/dropdown-menu'
import { ToggleGroup, ToggleGroupItem } from '@/components/ui/toggle-group'
import { useCp, type CpPreferences } from '@/lib/cp'
import { usePreference } from '@/lib/preferences'
import { shortcutsDialogOpen } from '@/lib/shortcuts'

const cp = useCp()
const theme = usePreference<CpPreferences['theme']>('theme', 'system')

const initials = computed(() =>
  (cp.value.user?.name ?? '')
    .split(/\s+/)
    .filter(Boolean)
    .map((part) => part[0])
    .slice(0, 2)
    .join('')
    .toUpperCase(),
)

const avatar = computed(() => {
  const seed = [...(cp.value.user?.email_address ?? '')].reduce(
    (hash, char) => (hash * 31 + char.charCodeAt(0)) >>> 0,
    7,
  )
  const hue = seed % 360
  const spot = (shift: number, x: number, y: number) =>
    `radial-gradient(circle at ${x}% ${y}%, hsl(${(hue + shift) % 360} 80% 55%) 0%, transparent 80%)`
  return {
    background: `${spot(0, 43, 75)}, ${spot(40, 56, 21)}, ${spot(320, 43, 41)}, ${spot(20, 72, 24)}, hsl(${hue} 75% 50%)`,
  }
})

const THEMES = [
  { value: 'light', label: 'Light', icon: Sun },
  { value: 'dark', label: 'Dark', icon: Moon },
  { value: 'system', label: 'System', icon: Monitor },
] as const

const signOut = () => router.delete('/cp/session')
</script>

<template>
  <DropdownMenu>
    <DropdownMenuTrigger
      class="flex size-10 shrink-0 cursor-pointer items-center justify-center rounded-lg outline-none hover:bg-white/7"
      aria-label="User menu"
    >
      <span
        class="flex size-7 items-center justify-center rounded-xl text-2xs font-medium text-white antialiased shape-squircle"
        :style="avatar"
        >{{ initials }}</span
      >
    </DropdownMenuTrigger>
    <DropdownMenuContent align="end" class="w-auto min-w-64 overflow-hidden bg-gray-50 p-0 dark:bg-gray-800">
      <header
        class="flex items-center gap-2 border-b border-gray-200 bg-white px-3.5 py-3 text-sm font-medium text-gray-900 dark:border-black dark:bg-gray-850 dark:text-gray-300"
      >
        <span
          class="flex size-7 shrink-0 items-center justify-center rounded-xl text-2xs font-medium text-white antialiased shape-squircle"
          :style="avatar"
          aria-hidden="true"
          >{{ initials }}</span
        >
        <span class="min-w-0">
          <span class="block truncate">{{ cp.user?.email_address }}</span>
          <span v-if="cp.user?.role" class="block truncate text-xs font-normal text-gray-500">{{ cp.user.role }}</span>
        </span>
      </header>
      <div class="rounded-b-xl bg-white p-1.5 shadow-ui-xs dark:bg-gray-850">
        <DropdownMenuItem as-child class="px-1"
          ><Link href="/cp/account/edit"
            ><span class="flex size-5 items-center justify-center p-1"><UserCircle class="size-4" /></span
            ><span class="px-2 text-gray-900 dark:text-gray-300">Manage profile</span></Link
          ></DropdownMenuItem
        >
        <DropdownMenuItem class="px-1" @click="shortcutsDialogOpen = true"
          ><span class="flex size-5 items-center justify-center p-1"><Keyboard class="size-4" /></span
          ><span class="px-2 text-gray-900 dark:text-gray-300">Keyboard shortcuts</span></DropdownMenuItem
        >
        <DropdownMenuItem class="px-1" @click="signOut"
          ><span class="flex size-5 items-center justify-center p-1"><LogOut class="size-4" /></span
          ><span class="px-2 text-gray-900 dark:text-gray-300">Sign out</span></DropdownMenuItem
        >
      </div>
      <footer class="px-1.75 py-2">
        <ToggleGroup
          type="single"
          :spacing="1"
          :model-value="theme"
          aria-label="Theme"
          class="flex w-full justify-between"
          @update:model-value="(value) => value && (theme = value as CpPreferences['theme'])"
        >
          <ToggleGroupItem
            v-for="option in THEMES"
            :key="option.value"
            :value="option.value"
            class="h-8 gap-1.5 px-2 text-sm font-normal text-gray-600 hover:bg-gray-200/60 hover:text-gray-900 data-[state=on]:bg-gray-200/80 data-[state=on]:text-gray-900 dark:text-gray-400 dark:hover:bg-white/7 dark:data-[state=on]:bg-white/10 dark:data-[state=on]:text-white"
            ><component :is="option.icon" class="size-4" />{{ option.label }}</ToggleGroupItem
          >
        </ToggleGroup>
      </footer>
    </DropdownMenuContent>
  </DropdownMenu>
</template>
