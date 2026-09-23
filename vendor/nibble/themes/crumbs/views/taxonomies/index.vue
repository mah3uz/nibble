<script setup lang="ts">
import PageHeading from '../../components/PageHeading.vue'

defineProps<{ page: { title: string | null } }>()
</script>

<template>
  <PageHeading :title="page.title" />
</template>
