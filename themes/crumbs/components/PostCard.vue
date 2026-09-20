<script setup lang="ts">
import { Link } from '@inertiajs/vue3'
import { Image } from '@nibble'
import type { PostsPost } from '../.nibble/types'
import { formatDate, isoDate } from '../lib/format'

defineProps<{ post: PostsPost }>()
</script>

<template>
  <article class="group relative min-w-0">
    <Link
      :href="post.uri ?? '#'"
      class="ring-ink/10 dark:bg-night-panel block overflow-hidden rounded-lg bg-white ring-1 transition-transform duration-200 motion-safe:hover:-translate-y-1 motion-safe:hover:-rotate-1 dark:ring-white/10"
    >
      <Image v-if="post.featured_image" :image="post.featured_image" class="aspect-3/2 w-full object-cover" />
      <div v-else class="bg-ink/5 flex aspect-3/2 items-center justify-center dark:bg-white/5" aria-hidden="true">
        <span class="font-display rotate-6 text-8xl">Aa.</span>
      </div>
      <div class="p-6 sm:p-7">
        <p class="mb-4 font-mono text-base text-accent sm:text-sm">
          <time :datetime="isoDate(post.published_at)">{{ formatDate(post.published_at) }}</time>
        </p>
        <h2 class="text-2xl font-semibold tracking-tight text-pretty group-hover:text-accent">{{ post.title }}</h2>
        <p v-if="post.excerpt" class="mt-4 line-clamp-2 text-base leading-7 text-gray-600 dark:text-gray-300">
          {{ post.excerpt }}
        </p>
        <p class="mt-6 text-base font-medium sm:text-sm">Read article <span aria-hidden="true">↗</span></p>
      </div>
    </Link>
  </article>
</template>
