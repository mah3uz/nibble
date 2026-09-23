<script setup lang="ts">
import { Link } from '@inertiajs/vue3'
</script>

<template>
  <div class="py-10">
    <p class="mb-6 font-mono text-base text-accent sm:text-sm">Error 404</p>
    <h1 class="font-display max-w-[18ch] text-6xl uppercase sm:text-8xl">Nothing but crumbs here</h1>
    <p class="mt-8 max-w-[48ch] text-lg leading-8 text-gray-600 dark:text-gray-300">
      Whatever was on this plate has been eaten, moved or never existed.
    </p>
    <div class="mt-8 flex flex-wrap gap-6">
      <Link class="py-3 underline" href="/">Back home</Link>
      <Link class="py-3 underline" href="/blog">Browse the archive</Link>
      <Link class="py-3 underline" href="/search">Search</Link>
    </div>
  </div>
</template>
