<script setup lang="ts">
import { PreviewBar, SeoHead } from '@nibble'
import SiteFooter from '../components/SiteFooter.vue'
import SiteHeader from '../components/SiteHeader.vue'
</script>

<template>
  <div
    class="bg-paper font-body text-ink dark:bg-night min-h-svh antialiased dark:text-gray-100 [&_a]:underline-offset-4"
  >
    <SeoHead />
    <PreviewBar />
    <a href="#main" class="bg-paper dark:bg-night absolute -top-24 left-4 z-50 p-4 focus:top-4">Skip to content</a>
    <SiteHeader />
    <main id="main" tabindex="-1" class="isolate mx-auto max-w-7xl px-5 py-12 sm:px-10 lg:py-16">
      <slot />
    </main>
    <SiteFooter />
  </div>
</template>
