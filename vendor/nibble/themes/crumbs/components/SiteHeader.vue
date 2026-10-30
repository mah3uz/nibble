<script setup lang="ts">
import { Link } from '@inertiajs/vue3'
import { Image, useGlobals, useNavigation } from '@nibble'
import { computed, nextTick, onBeforeUnmount, onMounted, ref, useTemplateRef } from 'vue'
import type { MainNavigationItem, SiteGlobals } from '@site/types'
import MenuLink from './MenuLink.vue'
import ThemeSwitch from './ThemeSwitch.vue'

const site = useGlobals<SiteGlobals>('site')
const links = useNavigation('main')
const menuOpen = ref(false)
const searchOpen = ref(false)
const submenu = ref<number | null>(null)
const enhanced = ref(false)
const searchInput = useTemplateRef<HTMLInputElement>('search')

// Until the page is interactive, search is a link to the search page, so it works without JavaScript.
const searchControl = computed(() =>
  enhanced.value
    ? { type: 'button', 'aria-expanded': searchOpen.value, 'aria-controls': 'header-search' }
    : { href: '/search' },
)

const submenuItems = (link: MainNavigationItem) =>
  link.url ? [{ ...link, children: [] }, ...link.children] : link.children

function toggled(index: number, event: Event) {
  if ((event.target as HTMLDetailsElement).open) submenu.value = index
  else if (submenu.value === index) submenu.value = null
}

function leaveSubmenu(event: FocusEvent) {
  if (!(event.currentTarget as Element).contains(event.relatedTarget as Node | null)) submenu.value = null
}

function clickOutside(event: MouseEvent) {
  if (!(event.target as Element).closest('details')) submenu.value = null
}

function escape(event: KeyboardEvent) {
  const open = (event.currentTarget as Element).querySelector('details[open]')
  if (open?.contains(document.activeElement)) open.querySelector('summary')?.focus()
  submenu.value = null
  menuOpen.value = false
  searchOpen.value = false
}

async function openSearch() {
  searchOpen.value = true
  menuOpen.value = false
  await nextTick()
  searchInput.value?.focus()
}

onMounted(() => {
  enhanced.value = true
  document.addEventListener('click', clickOutside)
})
onBeforeUnmount(() => document.removeEventListener('click', clickOutside))
</script>

<template>
  <header class="mx-auto max-w-7xl px-5 sm:px-10" @keydown.escape="escape">
    <div class="flex min-h-24 flex-wrap items-center justify-between gap-x-5 gap-y-2 py-4">
      <Link href="/" class="font-display flex items-center text-2xl uppercase sm:text-3xl">
        <Image
          v-if="site.logo"
          :image="site.logo"
          loading="eager"
          sizes="12rem"
          alt=""
          class="h-10 w-auto max-w-48 object-contain sm:h-12"
        />
        <span :class="{ 'sr-only': site.logo }">{{ site.name ?? 'Crumbs' }}</span>
      </Link>
      <nav aria-label="Main navigation" class="text-base max-lg:hidden sm:text-sm">
        <ul class="flex items-center gap-8" role="list">
          <li v-for="(link, index) in links" :key="`${index}-${link.url}`">
            <details
              v-if="link.children.length"
              name="main-menu"
              class="group relative"
              :open="submenu === index"
              @toggle="toggled(index, $event)"
              @focusout="leaveSubmenu"
            >
              <summary
                class="flex cursor-pointer list-none items-center gap-1 py-3 hover:text-accent [&::-webkit-details-marker]:hidden"
                :class="{ 'underline decoration-accent decoration-2 underline-offset-8': link.in_trail }"
              >
                {{ link.title }}
                <svg
                  class="size-4 transition-transform group-open:rotate-180"
                  viewBox="0 0 24 24"
                  fill="none"
                  stroke="currentColor"
                  stroke-width="2"
                  aria-hidden="true"
                >
                  <path d="m6 9 6 6 6-6" />
                </svg>
              </summary>
              <ul
                class="bg-paper dark:bg-night-panel absolute top-full -left-4 z-20 min-w-48 border-2 border-current py-2"
                role="list"
              >
                <li v-for="(item, position) in submenuItems(link)" :key="position">
                  <MenuLink
                    v-if="item.url"
                    :item="item"
                    class="block px-4 py-2 whitespace-nowrap -outline-offset-2 hover:text-accent"
                    :class="{ 'underline decoration-accent decoration-2': item.current }"
                    @click="submenu = null"
                  />
                  <p v-else class="px-4 pt-3 pb-1 font-mono whitespace-nowrap text-gray-600 dark:text-gray-400">
                    {{ item.title }}
                  </p>
                </li>
              </ul>
            </details>
            <MenuLink
              v-else-if="link.url"
              :item="link"
              class="block py-3 hover:text-accent"
              :class="{ 'underline decoration-accent decoration-2 underline-offset-8': link.in_trail }"
            />
          </li>
        </ul>
      </nav>
      <div class="flex items-center gap-1">
        <component
          :is="enhanced ? 'button' : 'a'"
          v-bind="searchControl"
          aria-label="Search the site"
          class="flex size-12 items-center justify-center hover:text-accent"
          @click.prevent="openSearch"
        >
          <svg class="size-6" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true">
            <circle cx="11" cy="11" r="7" />
            <path d="m20 20-3.5-3.5" />
          </svg>
        </component>
        <ThemeSwitch />
        <button
          type="button"
          :aria-expanded="menuOpen"
          aria-controls="mobile-navigation"
          class="min-h-12 px-2 lg:hidden"
          @click="((menuOpen = !menuOpen), (searchOpen = false))"
        >
          Menu
        </button>
      </div>
    </div>
    <nav v-show="menuOpen" id="mobile-navigation" aria-label="Mobile navigation" class="pb-5 lg:hidden">
      <ul role="list">
        <li v-for="(link, index) in links" :key="`${index}-${link.url}`">
          <MenuLink
            v-if="link.url"
            :item="link"
            class="block py-3 hover:text-accent"
            :class="{ 'text-accent': link.in_trail }"
            @click="menuOpen = false"
          />
          <p v-else class="py-3">{{ link.title }}</p>
          <ul v-if="link.children.length" class="mb-2 border-l-2 border-current/20 pl-4" role="list">
            <li v-for="(child, position) in link.children" :key="position">
              <MenuLink
                v-if="child.url"
                :item="child"
                class="block py-2.5 hover:text-accent"
                :class="{ 'text-accent': child.in_trail }"
                @click="menuOpen = false"
              />
              <p v-else class="pt-3 pb-1 font-mono text-gray-600 dark:text-gray-400">{{ child.title }}</p>
            </li>
          </ul>
        </li>
      </ul>
    </nav>
    <form v-show="searchOpen" id="header-search" action="/search" method="get" role="search" class="flex gap-3 pb-6">
      <label class="sr-only" for="header-query">Search articles</label>
      <input
        id="header-query"
        ref="search"
        name="q"
        type="search"
        maxlength="200"
        class="min-w-0 flex-1 border-b border-current bg-transparent px-1 py-3"
        placeholder="Search articles"
      />
      <button type="submit" class="px-3 py-3 underline">Search</button>
      <button type="button" class="px-3 py-3" @click="searchOpen = false">Close</button>
    </form>
    <div class="crumb-rule" aria-hidden="true"></div>
  </header>
</template>
