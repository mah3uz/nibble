<script setup lang="ts">
type Thumbnail = { thumbnail: string | null; title: string | null; url: string | null }

const props = defineProps<{ value: Thumbnail[] | null }>()
const LIMIT = 6
const shown = () => (props.value ?? []).slice(0, (props.value?.length ?? 0) > LIMIT ? LIMIT - 1 : LIMIT)
</script>

<template>
  <div v-if="value?.length" class="flex gap-2 text-2xs">
    <a
      v-for="(asset, index) in shown()"
      :key="index"
      :href="asset.url ?? undefined"
      target="_blank"
      rel="noopener"
      class="-my-1 h-8 max-w-3xs"
      :title="asset.title ?? undefined"
    >
      <img
        v-if="asset.thumbnail"
        :src="asset.thumbnail"
        :alt="asset.title ?? ''"
        loading="lazy"
        class="mx-auto max-h-8 max-w-full rounded-sm"
      />
      <span
        v-else
        class="flex h-8 min-w-8 items-center justify-center rounded-sm bg-gray-100 px-1.5 font-mono text-gray-600 uppercase dark:bg-gray-800 dark:text-gray-400"
        >{{ asset.title?.split('.').pop() }}</span
      >
    </a>
    <span
      v-if="value.length > LIMIT"
      class="-my-1 flex h-8 min-w-8 items-center justify-center px-1.5 font-mono text-gray-600 dark:text-gray-400"
      >+ {{ value.length - LIMIT + 1 }}</span
    >
  </div>
</template>
