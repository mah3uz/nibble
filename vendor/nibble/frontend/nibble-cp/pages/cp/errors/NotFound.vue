<script setup lang="ts">
import { Link } from '@inertiajs/vue3'
import { SearchX } from '@lucide/vue'
import EmptyState from '@/components/cp/page/EmptyState.vue'
import { Button } from '@/components/ui/button'
</script>

<template>
  <EmptyState :icon="SearchX" title="Not found" description="It may have been deleted, or the link is wrong.">
    <Button as-child><Link href="/cp">Back to dashboard</Link></Button>
  </EmptyState>
</template>
