<script setup lang="ts">
import { Link } from '@inertiajs/vue3'
import { useSite } from '@nibble'
import { computed } from 'vue'
import type { PagesPage, ViewProps } from '@site/types'
import PageHeading from '../components/PageHeading.vue'
import Pager from '../components/Pager.vue'

defineProps<ViewProps['search'] & { page: PagesPage }>()

const site = useSite()
const query = computed(() => site.value.params.q ?? '')
</script>

<template>
  <div>
    <PageHeading :title="page.title ?? 'Search'" :eyebrow="page.eyebrow ?? 'Find something worth reading'" />
    <form
      action="/search"
      method="get"
      role="search"
      aria-label="Search articles"
      class="mb-12 flex max-w-2xl items-end gap-4"
    >
      <div class="min-w-0 flex-1">
        <label for="query" class="mb-3 block">Search articles</label>
        <input
          id="query"
          type="search"
          name="q"
          maxlength="200"
          :value="query"
          placeholder="A word, an idea, a half-remembered title…"
          class="w-full border-b border-current bg-transparent px-1 py-4"
        />
      </div>
      <button type="submit" class="min-h-14 px-4 py-3 underline">Search</button>
    </form>
    <template v-if="query">
      <p v-if="!results.data.length" class="py-8 text-lg">Nothing found for “{{ query }}”. Try another word.</p>
      <template v-else>
        <p class="mb-8 text-lg">Results for “{{ query }}”</p>
        <ol class="grid gap-8" role="list">
          <li
            v-for="result in results.data"
            :key="`${result.type}-${result.id}`"
            class="border-b border-current/15 pb-6"
          >
            <h2 class="text-2xl font-semibold">
              <Link :href="result.uri ?? '#'" class="hover:text-accent">{{ result.title }}</Link>
            </h2>
            <!-- eslint-disable vue/no-v-html -- snippets are HTML-escaped by the server, with only <mark> added -->
            <p
              v-if="result.search_snippet"
              class="mt-2 text-gray-600 dark:text-gray-300"
              v-html="result.search_snippet"
            ></p>
            <!-- eslint-enable vue/no-v-html -->
          </li>
        </ol>
        <Pager :meta="results.meta" previous-label="← Previous results" next-label="More results →" />
      </template>
    </template>
    <p v-else class="text-lg text-gray-600 dark:text-gray-300">
      Search our articles, or start with <Link href="/topics" class="underline">a topic</Link>.
    </p>
  </div>
</template>
