<script setup lang="ts">
import { Link, usePage } from '@inertiajs/vue3'
import { useGlobals, useNavigation } from '@nibble'
import { nextTick, ref, useTemplateRef } from 'vue'
import type { SiteGlobals } from '@site/types'
import ThemeSwitch from './ThemeSwitch.vue'

const site = useGlobals<SiteGlobals>('site')
const links = useNavigation('main')
const page = usePage()
const menuOpen = ref(false)
const searchOpen = ref(false)
const searchInput = useTemplateRef<HTMLInputElement>('search')

function isCurrent(url: string) {
  const path = page.url.split('?')[0]
  return path === url || (url !== '/' && path.startsWith(`${url}/`))
}

async function openSearch() {
  searchOpen.value = true
  menuOpen.value = false
  await nextTick()
  searchInput.value?.focus()
}
</script>

<template>
  <header class="mx-auto max-w-7xl px-5 sm:px-10" @keydown.escape="((menuOpen = false), (searchOpen = false))">
    <div class="flex min-h-24 flex-wrap items-center justify-between gap-x-5 gap-y-2 py-4">
      <Link href="/" aria-label="Homepage" class="font-display text-2xl uppercase sm:text-3xl">{{
        site.name ?? 'Crumbs'
      }}</Link>
      <nav aria-label="Main navigation" class="flex items-center gap-8 text-base max-lg:hidden sm:text-sm">
        <Link
          v-for="link in links"
          :key="link.url"
          :href="link.url"
          class="py-3 hover:text-accent"
          :class="{ 'underline decoration-accent decoration-2 underline-offset-8': isCurrent(link.url) }"
          :aria-current="isCurrent(link.url) ? 'page' : undefined"
        >
          {{ link.title }}
        </Link>
      </nav>
      <div class="flex items-center gap-1">
        <a
          href="/search"
          aria-label="Search the site"
          :aria-expanded="searchOpen"
          aria-controls="header-search"
          class="flex size-12 items-center justify-center hover:text-accent"
          @click.prevent="openSearch"
        >
          <svg class="size-6" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true">
            <circle cx="11" cy="11" r="7" />
            <path d="m20 20-3.5-3.5" />
          </svg>
        </a>
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
      <Link
        v-for="link in links"
        :key="link.url"
        :href="link.url"
        class="block py-3 hover:text-accent"
        @click="menuOpen = false"
      >
        {{ link.title }}
      </Link>
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
