<script setup lang="ts">
import { Link } from '@inertiajs/vue3'
import type { ViewProps } from '@site/types'
import PageHeading from '../../components/PageHeading.vue'

defineProps<ViewProps['topics/index'] & { page: { title: string } }>()
</script>

<template>
  <div>
    <PageHeading :title="page.title" eyebrow="Follow your curiosity" />
    <p v-if="!topics.length" class="py-8 text-lg">Topics will appear here as the publication grows.</p>
    <div class="grid gap-x-8 md:grid-cols-2">
      <article v-for="topic in topics" :key="topic.id" class="border-t border-current/20 py-8">
        <h2 class="font-display text-4xl uppercase">
          <Link :href="topic.uri ?? '#'" class="hover:text-accent">{{ topic.title }} ↗</Link>
        </h2>
        <p v-if="topic.description" class="mt-4 max-w-[48ch] text-lg leading-8 text-gray-600 dark:text-gray-300">
          {{ topic.description }}
        </p>
      </article>
    </div>
  </div>
</template>
