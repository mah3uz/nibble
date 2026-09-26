<script setup lang="ts">
import { Link } from '@inertiajs/vue3'
import { Lock } from '@lucide/vue'
import EmptyState from '@/components/cp/page/EmptyState.vue'
import { Button } from '@/components/ui/button'
</script>

<template>
  <EmptyState :icon="Lock" title="You don't have permission" description="Ask an admin if you think this is a mistake.">
    <Button as-child><Link href="/cp">Back to dashboard</Link></Button>
  </EmptyState>
</template>
