<script setup lang="ts">
import { Link } from '@inertiajs/vue3'
import { useNavigation } from '@nibble'
import type { ViewProps } from '@site/types'
import { formatDate, isoDate } from '../../lib/format'
import { onSite } from '../../lib/links'

defineProps<ViewProps['errors/404']>()

const links = useNavigation('main')
</script>

<template>
  <div class="py-10">
    <p class="mb-6 font-mono text-base text-accent sm:text-sm">Error 404</p>
    <h1 class="font-display max-w-[18ch] text-6xl uppercase sm:text-8xl">Nothing but crumbs here</h1>
    <p class="mt-8 max-w-[48ch] text-lg leading-8 text-gray-600 dark:text-gray-300">
      Whatever was on this plate has been eaten, moved or never existed.
    </p>
    <div class="mt-8 flex flex-wrap gap-6">
      <Link class="py-3 underline" href="/">Back home</Link>
      <template v-for="link in links" :key="link.url">
        <Link v-if="onSite(link.url)" class="py-3 underline" :href="link.url">{{ link.title }}</Link>
        <a v-else class="py-3 underline" :href="link.url">{{ link.title }}</a>
      </template>
    </div>
    <form action="/search" method="get" role="search" aria-label="Search articles" class="mt-8 flex max-w-xl gap-4">
      <label for="not-found-query" class="sr-only">Search articles</label>
      <input
        id="not-found-query"
        type="search"
        name="q"
        maxlength="200"
        placeholder="Search for what you were after"
        class="min-w-0 flex-1 border-b border-current bg-transparent px-1 py-4"
      />
      <button type="submit" class="min-h-14 px-4 py-3 underline">Search</button>
    </form>
    <section v-if="latest?.length" class="mt-16">
      <h2 class="mb-4 font-mono text-base text-accent sm:text-sm">Or read the latest</h2>
      <ul role="list">
        <li v-for="post in latest" :key="post.id" class="border-t border-current/15 py-4">
          <Link :href="post.uri ?? '#'" class="text-2xl font-semibold hover:text-accent">{{ post.title }}</Link>
          <time
            :datetime="isoDate(post.published_at)"
            class="mt-1 block font-mono text-base text-gray-600 sm:text-sm dark:text-gray-400"
            >{{ formatDate(post.published_at) }}</time
          >
        </li>
      </ul>
    </section>
  </div>
</template>
