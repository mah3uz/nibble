<script setup lang="ts">
defineProps<{ title?: string }>()
</script>

<template>
  <section class="mb-8">
    <h2 v-if="title" class="mb-3 text-lg text-gray-900 dark:text-white">{{ title }}</h2>
    <div class="relative w-full rounded-2xl bg-gray-150 p-1.75 max-[600px]:p-1.25 dark:bg-gray-950/35">
      <div class="overflow-x-auto">
        <table class="data-table">
          <slot />
        </table>
      </div>
    </div>
  </section>
</template>
