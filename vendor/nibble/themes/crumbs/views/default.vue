<script setup lang="ts">
import { Blocks } from '@nibble'
import type { RichTextValue, SetBlock } from '@nibble'
import Prose from '../components/Prose.vue'
import PageHeading from '../components/PageHeading.vue'

defineProps<{
  page: {
    title: string | null
    eyebrow?: string | null
    intro?: string | null
    excerpt?: string | null
    body?: RichTextValue
    blocks?: SetBlock[] | null
  }
}>()
</script>

<template>
  <div>
    <PageHeading :title="page.title" :eyebrow="page.eyebrow" :description="page.intro ?? page.excerpt" />
    <div class="prose max-w-[65ch] dark:prose-invert">
      <Prose v-if="page.body" :value="page.body" />
      <Blocks :blocks="page.blocks" />
    </div>
  </div>
</template>
