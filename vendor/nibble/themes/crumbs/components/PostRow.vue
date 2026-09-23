<script setup lang="ts">
import { Link } from '@inertiajs/vue3'
import type { PostsPost } from '@site/types'
import { formatDate, isoDate } from '../lib/format'

defineProps<{ post: PostsPost }>()
</script>

<template>
  <article class="grid gap-3 border-b border-current/15 py-7 sm:grid-cols-[9rem_1fr] sm:gap-8">
    <p class="font-mono text-base text-gray-600 sm:text-sm dark:text-gray-400">
      <time :datetime="isoDate(post.published_at)">{{
        formatDate(post.published_at, { month: 'short', day: 'numeric' })
      }}</time>
    </p>
    <div>
      <h3 class="max-w-[42ch] text-2xl font-semibold tracking-tight text-pretty">
        <Link :href="post.uri ?? '#'" class="hover:text-accent">{{ post.title }}</Link>
      </h3>
      <p v-if="post.excerpt" class="mt-3 max-w-[65ch] text-base leading-7 text-gray-600 dark:text-gray-300">
        {{ post.excerpt }}
      </p>
    </div>
  </article>
</template>
