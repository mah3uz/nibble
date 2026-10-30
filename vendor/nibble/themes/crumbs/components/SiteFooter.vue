<script setup lang="ts">
import { useGlobals, useNavigation } from '@nibble'
import { computed } from 'vue'
import type { SiteGlobals } from '@site/types'
import MenuLink from './MenuLink.vue'

const site = useGlobals<SiteGlobals>('site')
const footer = useNavigation('footer')
const main = useNavigation('main')
const links = computed(() =>
  footer.value.length ? footer.value : main.value.map((link) => ({ ...link, children: [] as never[] })),
)
const columns = computed(() => links.value.some((link) => link.kind === 'heading' || link.children.length))
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
      <nav
        aria-label="Footer navigation"
        class="flex flex-wrap text-base sm:text-sm"
        :class="columns ? 'gap-x-10 gap-y-6' : 'gap-x-6 gap-y-2'"
      >
        <template v-for="(link, position) in links" :key="position">
          <div v-if="link.kind === 'heading' || link.children.length" class="min-w-36">
            <h2 class="py-3 font-mono text-accent">
              <template v-if="link.kind === 'heading'">{{ link.title }}</template>
              <MenuLink v-else :item="link" class="hover:underline" />
            </h2>
            <ul role="list">
              <li v-for="(child, index) in link.children" :key="index">
                <MenuLink v-if="child.kind !== 'heading'" :item="child" class="block py-2 hover:text-accent" />
              </li>
            </ul>
          </div>
          <MenuLink v-else :item="link" class="py-3 hover:text-accent" />
        </template>
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
      © {{ site.name ?? 'Crumbs' }} · Made with Nibble
    </p>
  </footer>
</template>
