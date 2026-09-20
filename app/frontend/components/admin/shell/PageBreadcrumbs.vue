<script setup lang="ts">
import { Link } from '@inertiajs/vue3'
import { computed, ref } from 'vue'
import AdminIcon from '@/components/admin/icons/AdminIcon.vue'
import { DropdownMenu, DropdownMenuContent, DropdownMenuItem, DropdownMenuTrigger } from '@/components/ui/dropdown-menu'
import { useAdmin, type NavItem } from '@/lib/admin'
import type { Breadcrumb } from '@/lib/breadcrumbs'
import { NAV_ICONS } from './icons'

const props = defineProps<{ trail: Breadcrumb[] }>()
const admin = useAdmin()

function siblingsOf(crumb: Breadcrumb): { current: NavItem; items: NavItem[] } | null {
  const matches = (item: NavItem) => (crumb.url ? item.url === crumb.url : item.title === crumb.label)
  for (const section of admin.value.nav) {
    for (const item of section.items) {
      if (matches(item)) return { current: item, items: section.items }
      const child = item.children?.find(matches)
      if (child) return { current: child, items: item.children! }
    }
  }
  return null
}

const crumbs = computed(() =>
  props.trail.map((crumb) => {
    const found = siblingsOf(crumb)
    return { ...crumb, url: crumb.url ?? found?.current.url, switcher: found && found.items.length > 1 ? found : null }
  }),
)

const icon = (item: NavItem) => NAV_ICONS[item.icon] ?? item.icon
const anchors = ref<(HTMLElement | undefined)[]>([])
</script>

<template>
  <nav v-if="trail.length" aria-label="Breadcrumb" class="hidden min-w-0 items-center gap-2 md:flex">
    <div v-for="(crumb, index) in crumbs" :key="index" class="flex min-w-0 items-center gap-1 lg:gap-2">
      <span class="shrink-0 text-[13px] text-white/30" aria-hidden="true">/</span>
      <div :ref="(el) => (anchors[index] = el as HTMLElement)" class="flex min-w-0 items-center gap-1 lg:gap-2">
        <Link
          v-if="crumb.url"
          :href="crumb.url"
          :class="[
            'inline-flex h-8 items-center truncate rounded-lg px-2 text-[13px] font-medium text-white/85 hover:bg-white/7 hover:text-white',
            crumb.switcher && 'mr-1.75',
          ]"
          >{{ crumb.label }}</Link
        >
        <span v-else class="inline-flex h-8 items-center truncate px-2 text-[13px] font-medium text-white/85">{{
          crumb.label
        }}</span>
        <DropdownMenu v-if="crumb.switcher">
          <DropdownMenuTrigger
            class="-ml-4 inline-flex h-8 w-6 shrink-0 cursor-pointer items-center justify-center rounded-lg text-white opacity-60 hover:bg-gray-300/5 hover:opacity-70"
            :aria-label="`Options for ${crumb.label}`"
          >
            <AdminIcon name="chevron-up-down" class="size-3" />
          </DropdownMenuTrigger>
          <DropdownMenuContent
            align="start"
            :reference="anchors[index]"
            class="w-auto min-w-64 overflow-hidden bg-gray-50 p-0 dark:bg-gray-800"
          >
            <DropdownMenuItem
              as-child
              class="rounded-none border-b border-gray-200 bg-white px-3.5 py-3 font-medium text-gray-900 dark:border-black dark:bg-gray-850 dark:text-gray-300"
            >
              <Link :href="crumb.switcher.current.url">
                <span
                  class="-ms-1 me-2 flex size-6 items-center justify-center rounded-lg bg-gray-100 p-1 text-gray-700 dark:bg-gray-800 dark:text-gray-400"
                  ><AdminIcon :name="icon(crumb.switcher.current)" class="size-4"
                /></span>
                {{ crumb.switcher.current.title }}
              </Link>
            </DropdownMenuItem>
            <div class="rounded-b-xl bg-white p-1.5 shadow-ui-xs dark:bg-gray-850">
              <DropdownMenuItem
                v-for="item in crumb.switcher.items.filter((entry) => entry.url !== crumb.switcher!.current.url)"
                :key="item.url"
                as-child
                class="px-1"
              >
                <Link :href="item.url">
                  <span class="flex size-5 items-center justify-center p-1"
                    ><AdminIcon :name="icon(item)" class="size-4"
                  /></span>
                  <span class="px-2 text-gray-900 dark:text-gray-300">{{ item.title }}</span>
                </Link>
              </DropdownMenuItem>
            </div>
          </DropdownMenuContent>
        </DropdownMenu>
      </div>
    </div>
  </nav>
</template>
