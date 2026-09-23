<script setup lang="ts">
import { Link } from '@inertiajs/vue3'
import { useGlobals, useNavigation } from '@nibble'
import type { SiteGlobals } from '@site/types'

const site = useGlobals<SiteGlobals>('site')
const links = useNavigation('main')
const year = new Date().getFullYear()
</script>

<template>
  <footer class="mx-auto max-w-7xl px-5 pt-12 pb-8 sm:px-10">
    <div class="crumb-rule" aria-hidden="true"></div>
    <div class="flex flex-wrap items-start justify-between gap-8 py-8">
      <div>
        <p class="font-display text-3xl uppercase">{{ site.name ?? 'Crumbs' }}</p>
        <p v-if="site.tagline" class="mt-1 max-w-[40ch] text-base text-gray-600 sm:text-sm dark:text-gray-400">
          {{ site.tagline }}
        </p>
      </div>
      <nav aria-label="Footer navigation" class="flex flex-wrap gap-x-6 gap-y-2 text-base sm:text-sm">
        <Link v-for="link in links" :key="link.url" class="py-3 hover:text-accent" :href="link.url">{{
          link.title
        }}</Link>
      </nav>
      <ul v-if="site.social_links?.length" class="flex gap-4 text-base sm:text-sm" role="list">
        <li v-for="social in site.social_links" :key="social.id">
          <a :href="String(social.url)" class="py-3 text-gray-600 hover:text-accent dark:text-gray-300">{{
            social.label
          }}</a>
        </li>
      </ul>
    </div>
    <p class="text-base text-gray-600 sm:text-sm dark:text-gray-400">
      © {{ year }} {{ site.name ?? 'Crumbs' }} · Made with Nibble
    </p>
  </footer>
</template>
