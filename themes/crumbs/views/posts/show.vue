<script setup lang="ts">
import { Link } from '@inertiajs/vue3'
import { Image, RichText } from '@nibble'
import { computed } from 'vue'
import type { PostsPost, ViewProps } from '../../.nibble/types'
import PostCard from '../../components/PostCard.vue'
import { formatDate, isoDate } from '../../lib/format'

const props = defineProps<ViewProps['posts/show'] & { page: PostsPost }>()

const readingTime = computed(() => {
  const words = (props.page.body ?? '')
    .replace(/<[^>]+>/g, ' ')
    .split(/\s+/)
    .filter(Boolean).length
  return Math.max(1, Math.round(words / 230))
})
</script>

<template>
  <article>
    <header class="mx-auto max-w-4xl pb-10 text-center sm:pb-14">
      <div class="mb-6 flex flex-wrap justify-center gap-3 font-mono text-base sm:text-sm">
        <Link
          v-for="topic in page.topics"
          :key="topic.id"
          :href="topic.uri ?? '#'"
          class="rounded-full border border-current/20 px-4 py-2 text-accent odd:-rotate-2"
        >
          {{ topic.title }}
        </Link>
      </div>
      <h1 class="font-display text-5xl text-pretty uppercase sm:text-7xl">{{ page.title }}</h1>
      <p
        v-if="page.excerpt"
        class="mx-auto mt-7 max-w-[55ch] text-lg leading-8 text-balance text-gray-600 dark:text-gray-300"
      >
        {{ page.excerpt }}
      </p>
      <div class="mt-8 flex flex-wrap items-center justify-center gap-4 text-base sm:text-sm">
        <template v-if="page.authors">
          <Link :href="page.authors.uri ?? '#'" class="font-medium underline">{{ page.authors.title }}</Link>
          <span aria-hidden="true">·</span>
        </template>
        <time :datetime="isoDate(page.published_at)">{{
          formatDate(page.published_at, { month: 'long', day: 'numeric', year: 'numeric' })
        }}</time>
        <span aria-hidden="true">·</span>
        <p>{{ readingTime }} min read</p>
      </div>
    </header>
    <Image
      v-if="page.featured_image"
      :image="page.featured_image"
      loading="eager"
      class="mx-auto aspect-9/5 w-full rounded-lg object-cover"
    />
    <div class="mx-auto max-w-[65ch] pt-10 sm:pt-14">
      <div class="prose dark:prose-invert">
        <RichText :value="page.body" />
      </div>
    </div>
    <section v-if="related.length" class="mt-16 border-t border-current/20 pt-10" aria-labelledby="related-heading">
      <h2 id="related-heading" class="font-display mb-8 text-4xl uppercase">More from this batch</h2>
      <div class="grid gap-8 md:grid-cols-2 lg:grid-cols-3">
        <PostCard v-for="post in related" :key="post.id" :post="post" />
      </div>
    </section>
  </article>
</template>
