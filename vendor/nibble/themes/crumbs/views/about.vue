<script setup lang="ts">
import { Link } from '@inertiajs/vue3'
import { Blocks } from '@nibble'
import type { PagesPage, ViewProps } from '@site/types'
import ContactForm from '../components/ContactForm.vue'
import PageHeading from '../components/PageHeading.vue'

defineProps<ViewProps['about'] & { page: PagesPage }>()
</script>

<template>
  <div>
    <PageHeading :title="page.title" :eyebrow="page.eyebrow ?? 'A little introduction'" :description="page.intro" />
    <div class="grid items-start gap-8 lg:grid-cols-[3fr_2fr] lg:gap-12">
      <div class="prose max-w-[65ch] dark:prose-invert"><Blocks :blocks="page.blocks" /></div>
      <aside class="rounded-lg border border-current/20 p-8">
        <p class="mb-4 font-mono text-base text-accent sm:text-sm">House rules</p>
        <p class="font-display text-5xl uppercase">Take small bites.<br />Chew slowly.<br />Share the rest.</p>
      </aside>
    </div>
    <section v-if="authors.length" class="mt-16 border-t border-current/20 pt-10">
      <h2 class="font-display text-4xl uppercase">Contributors</h2>
      <ul role="list" class="mt-8 grid gap-8 md:grid-cols-2">
        <li v-for="author in authors" :key="author.id">
          <h3 class="text-xl font-semibold">
            <Link :href="author.uri ?? '#'" class="hover:text-accent">{{ author.title }}</Link>
          </h3>
          <p v-if="author.bio" class="mt-2 max-w-[48ch] leading-7 text-gray-600 dark:text-gray-300">{{ author.bio }}</p>
        </li>
      </ul>
    </section>
    <section class="mt-16 border-t border-current/20 pt-10">
      <h2 class="font-display mb-8 text-4xl uppercase">Say hello</h2>
      <ContactForm :form="contact" />
    </section>
  </div>
</template>
