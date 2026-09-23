<script setup lang="ts">
import type { AuthorsAuthor, ViewProps } from '../../.nibble/types'
import Pager from '../../components/Pager.vue'
import PostCard from '../../components/PostCard.vue'

defineProps<ViewProps['authors/show'] & { page: AuthorsAuthor }>()
</script>

<template>
  <div>
    <header class="mb-12">
      <p class="mb-4 font-mono text-base text-accent sm:text-sm">Contributor</p>
      <h1 class="font-display text-6xl uppercase">{{ page.title }}</h1>
      <p v-if="page.bio" class="mt-5 max-w-[55ch] text-lg leading-8 text-gray-600 dark:text-gray-300">{{ page.bio }}</p>
      <p v-if="page.website" class="mt-4"><a :href="page.website" class="underline">Website ↗</a></p>
    </header>
    <p v-if="!posts.data.length" class="py-10 text-lg">No published articles yet.</p>
    <div class="grid gap-8 md:grid-cols-2 lg:grid-cols-3">
      <PostCard v-for="post in posts.data" :key="post.id" :post="post" />
    </div>
    <Pager :meta="posts.meta" />
  </div>
</template>
