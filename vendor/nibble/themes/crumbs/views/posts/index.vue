<script setup lang="ts">
import { computed } from 'vue'
import type { PagesPage, ViewProps } from '@site/types'
import PageHeading from '../../components/PageHeading.vue'
import Pager from '../../components/Pager.vue'
import PostRow from '../../components/PostRow.vue'

const props = defineProps<ViewProps['posts/index'] & { page: PagesPage }>()

const years = computed(() => {
  const groups = new Map<string, typeof props.posts.data>()
  for (const post of props.posts.data) {
    const year = post.published_at?.slice(0, 4) ?? 'Undated'
    groups.set(year, [...(groups.get(year) ?? []), post])
  }
  return [...groups.entries()]
})
</script>

<template>
  <div>
    <PageHeading :title="page.title" :eyebrow="page.eyebrow ?? 'The complete collection'" :description="page.intro" />
    <p v-if="!posts.data.length" class="py-10 text-lg">No articles yet. Check back soon.</p>
    <section v-for="[year, items] in years" :key="year" class="mb-12" :aria-label="`Articles from ${year}`">
      <h2 class="font-display border-b border-current/20 pb-5 text-4xl">{{ year }}</h2>
      <PostRow v-for="post in items" :key="post.id" :post="post" />
    </section>
    <Pager :meta="posts.meta" />
  </div>
</template>
