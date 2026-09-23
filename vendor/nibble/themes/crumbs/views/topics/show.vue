<script setup lang="ts">
import { Link } from '@inertiajs/vue3'
import type { TopicsTopic, ViewProps } from '@site/types'
import PageHeading from '../../components/PageHeading.vue'
import Pager from '../../components/Pager.vue'
import PostCard from '../../components/PostCard.vue'

defineProps<ViewProps['topics/show'] & { page: TopicsTopic }>()
</script>

<template>
  <div>
    <PageHeading :title="page.title" eyebrow="Articles filed under" :description="page.description" />
    <p v-if="!posts.data.length" class="py-10 text-lg">Nothing filed here yet. Try another topic.</p>
    <div class="grid gap-8 md:grid-cols-2 lg:grid-cols-3">
      <PostCard v-for="post in posts.data" :key="post.id" :post="post" />
    </div>
    <Pager :meta="posts.meta" />
    <p class="mt-12"><Link class="inline-flex min-h-12 items-center underline" href="/topics">← All topics</Link></p>
  </div>
</template>
