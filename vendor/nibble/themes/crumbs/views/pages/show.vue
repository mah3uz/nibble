<script setup lang="ts">
import { Blocks } from '@nibble'
import type { PagesPage } from '../../.nibble/types'
import PageHeading from '../../components/PageHeading.vue'

defineProps<{ page: PagesPage }>()
</script>

<template>
  <div>
    <PageHeading :title="page.title" :eyebrow="page.eyebrow" :description="page.intro" />
    <div class="prose max-w-[65ch] dark:prose-invert">
      <Blocks :blocks="page.blocks" />
    </div>
  </div>
</template>
