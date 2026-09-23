<script setup lang="ts">
import { Link } from '@inertiajs/vue3'
import type { PagesPage, ViewProps } from '@site/types'
import PostCard from '../components/PostCard.vue'
import { formatDate, isoDate } from '../lib/format'

defineProps<ViewProps['home'] & { page: PagesPage }>()
</script>

<template>
  <div>
    <header class="relative mb-14 border-b border-current/20 pb-12 lg:mb-16 lg:pb-14">
      <div class="mb-6 flex items-center gap-4 font-mono text-base sm:text-sm">
        <span class="bg-hot-pink size-2 rounded-full" aria-hidden="true"></span>
        <p>{{ page.eyebrow ?? 'An independent publication' }}</p>
      </div>
      <div class="grid items-end gap-8 lg:grid-cols-[3fr_2fr] lg:gap-12">
        <h1 class="font-display max-w-[13ch] text-7xl text-balance uppercase sm:text-8xl lg:text-9xl">
          {{ page.title }}
        </h1>
        <div class="pb-2">
          <p v-if="page.intro" class="max-w-[38ch] text-lg leading-8 text-gray-600 dark:text-gray-300">
            {{ page.intro }}
          </p>
          <p class="mt-6 font-mono text-base sm:text-sm">
            <Link href="/about" class="underline decoration-accent decoration-2"
              >Who's behind this <span aria-hidden="true">↗</span></Link
            >
          </p>
        </div>
      </div>
      <div
        aria-hidden="true"
        class="font-display pointer-events-none absolute -top-4 -right-1 rotate-12 text-7xl text-accent sm:right-2"
      >
        ✳
      </div>
    </header>

    <p v-if="!featured.length" class="py-12 text-lg">The first article is on its way. Check back soon.</p>
    <section v-for="post in featured" :key="post.id" aria-label="Featured article" class="mb-16">
      <div class="mb-6 flex items-center justify-between gap-6">
        <h2 class="font-mono text-base sm:text-sm">Fresh from the oven</h2>
        <p class="font-mono text-base text-gray-600 sm:text-sm dark:text-gray-400">01 / The latest</p>
      </div>
      <article class="relative py-4">
        <p
          v-for="topic in post.topics.slice(0, 1)"
          :key="topic.id"
          class="text-ink mb-6 w-fit -rotate-3 rounded-full border border-current/20 bg-[#eee98b] px-4 py-2 font-mono text-base sm:text-sm dark:bg-white/10 dark:text-gray-100"
        >
          <Link :href="topic.uri ?? '#'" class="hover:underline">{{ topic.title }}</Link>
        </p>
        <h3 class="max-w-[24ch] text-4xl font-semibold tracking-tight text-pretty lg:text-5xl">
          <Link :href="post.uri ?? '#'" class="hover:text-accent">{{ post.title }}</Link>
        </h3>
        <p v-if="post.excerpt" class="mt-6 max-w-[42ch] text-lg leading-8 text-gray-600 dark:text-gray-300">
          {{ post.excerpt }}
        </p>
        <p class="mt-6 font-mono text-base text-gray-600 sm:text-sm dark:text-gray-400">
          <time :datetime="isoDate(post.published_at)">{{ formatDate(post.published_at) }}</time>
          <template v-if="post.authors"> · {{ post.authors.title }}</template>
        </p>
        <p class="mt-8">
          <Link
            :href="post.uri ?? '#'"
            class="inline-flex min-h-12 items-center gap-6 border-b-2 border-accent py-2 font-medium"
          >
            Read the story <span aria-hidden="true">↗</span>
          </Link>
        </p>
      </article>
    </section>

    <section v-if="recent.length" aria-labelledby="more-heading" class="pt-6">
      <div class="crumb-rule mb-8" aria-hidden="true"></div>
      <div class="mb-8 flex flex-wrap items-center justify-between gap-4">
        <h2 id="more-heading" class="font-display text-4xl uppercase">More crumbs</h2>
        <Link href="/blog" class="py-3 underline">The archive ↗</Link>
      </div>
      <div class="grid gap-8 md:grid-cols-2 lg:grid-cols-3">
        <PostCard v-for="post in recent" :key="post.id" :post="post" />
      </div>
    </section>

    <section v-if="topics.length" aria-labelledby="topics-heading" class="mt-16 border-y border-current/20 py-10">
      <div class="flex flex-wrap items-baseline justify-between gap-4">
        <h2 id="topics-heading" class="font-display text-4xl uppercase">Pick a flavour</h2>
        <Link href="/topics" class="py-3 underline">All topics ↗</Link>
      </div>
      <div class="mt-6 flex flex-wrap gap-4">
        <Link
          v-for="topic in topics"
          :key="topic.id"
          :href="topic.uri ?? '#'"
          class="rounded-full border border-current/30 px-5 py-3 odd:-rotate-2 even:rotate-2 hover:text-accent"
        >
          {{ topic.title }} <span aria-hidden="true">↗</span>
        </Link>
      </div>
    </section>
  </div>
</template>
