<script setup lang="ts">
import { Head, usePage } from '@inertiajs/vue3'
import { computed } from 'vue'
import type { SeoProps } from './types'

const page = usePage<{ seo?: SeoProps }>()
const seo = computed(() => page.props.seo)
</script>

<template>
  <Head v-if="seo" :title="seo.title">
    <meta v-if="seo.description" head-key="description" name="description" :content="seo.description" />
    <link v-if="seo.canonical" head-key="canonical" rel="canonical" :href="seo.canonical" />
    <meta v-if="seo.robots" head-key="robots" name="robots" :content="seo.robots" />
  </Head>
</template>
