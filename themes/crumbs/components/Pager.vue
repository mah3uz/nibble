<script setup lang="ts">
import { Link } from '@inertiajs/vue3'
import { Pagination, type PaginationMeta } from '@nibble'

withDefaults(defineProps<{ meta: PaginationMeta; previousLabel?: string; nextLabel?: string }>(), {
  previousLabel: '← Newer articles',
  nextLabel: 'Older articles →',
})
</script>

<template>
  <Pagination :meta="meta">
    <template #default="{ href, current }">
      <div class="mt-12 flex flex-wrap items-center justify-between gap-6 border-t border-current/20 pt-6">
        <Link v-if="current > 1" :href="href(current - 1)" rel="prev" class="py-3 hover:text-accent">{{
          previousLabel
        }}</Link>
        <p class="font-mono text-base text-gray-600 sm:text-sm dark:text-gray-400">
          Page {{ current }} of {{ meta.last_page }}
        </p>
        <Link v-if="current < meta.last_page" :href="href(current + 1)" rel="next" class="py-3 hover:text-accent">{{
          nextLabel
        }}</Link>
      </div>
    </template>
  </Pagination>
</template>
