<script setup lang="ts">
import { Link, usePage } from '@inertiajs/vue3'
import {
  Sidebar,
  SidebarContent,
  SidebarGroup,
  SidebarGroupContent,
  SidebarGroupLabel,
  SidebarMenu,
  SidebarMenuButton,
  SidebarMenuItem,
  SidebarMenuSub,
  SidebarMenuSubButton,
  SidebarMenuSubItem,
} from '@/components/ui/sidebar'
import SiteSlot from '@/components/admin/SiteSlot.vue'
import { useAdmin } from '@/lib/admin'
import AdminIcon from '@/components/admin/icons/AdminIcon.vue'
import { NAV_ICONS } from './icons'

const admin = useAdmin()
const page = usePage()

const isActive = (active: string) => (active === '/admin' ? page.url === '/admin' : page.url.startsWith(active))
const hasActiveChild = (item: (typeof admin.value.nav)[number]['items'][number]) =>
  (item.children ?? []).some((child) => isActive(child.active))
</script>

<template>
  <Sidebar
    collapsible="offcanvas"
    class="top-14 h-[calc(100svh-3.5rem)] overflow-hidden rounded-tl-2xl border-r-0 group-data-[side=left]:border-r-0"
  >
    <SidebarContent class="gap-6 px-3 py-6">
      <SidebarGroup v-for="section in admin.nav" :key="section.handle" class="p-0">
        <SidebarGroupLabel
          v-if="section.label"
          class="mb-1 h-5 px-2 text-sm font-medium text-gray-900 dark:text-white"
          >{{ section.label }}</SidebarGroupLabel
        >
        <SidebarGroupContent>
          <SidebarMenu class="gap-0">
            <SidebarMenuItem v-for="item in section.items" :key="item.url">
              <SidebarMenuButton
                as-child
                :is-active="isActive(item.active)"
                class="h-7 gap-3 rounded-md px-2 py-1 text-sm text-gray-700 hover:bg-gray-400/10 hover:text-gray-925 dark:text-gray-300 data-active:bg-gray-400/15 data-active:font-medium data-active:text-gray-925 dark:data-active:text-white [&_svg]:text-gray-500 data-active:[&_svg]:text-gray-925 dark:data-active:[&_svg]:text-white"
              >
                <Link :href="item.url">
                  <AdminIcon :name="NAV_ICONS[item.icon] ?? item.icon" class="size-4" />
                  <span>{{ item.title }}</span>
                </Link>
              </SidebarMenuButton>
              <SidebarMenuSub
                v-if="item.children?.length && (isActive(item.active) || hasActiveChild(item))"
                class="mx-0 ms-3.75 mt-1.5 mb-1 translate-x-0 gap-1.5 border-gray-300 px-0 py-0 dark:border-gray-700"
              >
                <SidebarMenuSubItem v-for="child in item.children" :key="child.url">
                  <SidebarMenuSubButton
                    as-child
                    :is-active="isActive(child.active)"
                    class="h-auto translate-x-0 rounded-md py-0 ps-5 pe-2 text-[13px] text-gray-700 hover:bg-transparent hover:text-gray-925 dark:text-gray-300 data-active:bg-transparent data-active:font-medium data-active:text-gray-925 dark:data-active:text-white [&>svg]:hidden"
                  >
                    <Link :href="child.url">
                      <span>{{ child.title }}</span>
                    </Link>
                  </SidebarMenuSubButton>
                </SidebarMenuSubItem>
              </SidebarMenuSub>
            </SidebarMenuItem>
          </SidebarMenu>
        </SidebarGroupContent>
      </SidebarGroup>
      <SiteSlot name="SidebarExtra" />
    </SidebarContent>
  </Sidebar>
</template>
