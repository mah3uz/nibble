<script setup lang="ts">
import { Link, usePage } from '@inertiajs/vue3'
import { computed } from 'vue'
import type { PaginationMeta } from './types'

const props = withDefaults(defineProps<{ meta: PaginationMeta; param?: string; label?: string }>(), {
  param: 'page',
  label: 'Pagination',
})

const page = usePage()

function href(number: number) {
  const url = new URL(page.url, 'http://nibble.local')
  if (number > 1) url.searchParams.set(props.param, String(number))
  else url.searchParams.delete(props.param)
  return `${url.pathname}${url.search}`
}

const pages = computed(() => Array.from({ length: props.meta.last_page }, (_, index) => index + 1))
</script>

<template>
  <nav v-if="meta.last_page > 1" :aria-label="label">
    <slot :pages="pages" :href="href" :current="meta.current_page">
      <Link v-if="meta.current_page > 1" :href="href(meta.current_page - 1)" rel="prev">Previous</Link>
      <Link
        v-for="number in pages"
        :key="number"
        :href="href(number)"
        :aria-current="number === meta.current_page ? 'page' : undefined"
      >
        {{ number }}
      </Link>
      <Link v-if="meta.current_page < meta.last_page" :href="href(meta.current_page + 1)" rel="next">Next</Link>
    </slot>
  </nav>
</template>
