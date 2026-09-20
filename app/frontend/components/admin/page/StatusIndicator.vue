<script setup lang="ts">
import { computed } from 'vue'

// Vue casts an omitted boolean prop to false; `live` must stay undefined when the caller doesn't know it.
const props = withDefaults(
  defineProps<{
    status: 'draft' | 'in_review' | 'approved' | 'scheduled' | 'published' | 'unpublished'
    live?: boolean
    hasChanges?: boolean
  }>(),
  { live: undefined },
)

const DOT = {
  draft: 'bg-muted-foreground/40',
  in_review: 'bg-blue-500',
  approved: 'bg-teal-500',
  scheduled: 'bg-amber-500',
  published: 'bg-green-500',
  unpublished: 'bg-muted-foreground/40',
}

const LABEL = {
  draft: 'Draft',
  in_review: 'In review',
  approved: 'Approved',
  scheduled: 'Scheduled',
  published: 'Published',
  unpublished: 'Unpublished',
}

const label = computed(() => {
  if (props.status === 'published' && props.live === false) return 'Not live yet'
  return LABEL[props.status]
})
</script>

<template>
  <span class="inline-flex items-center gap-1.5 text-sm">
    <span class="size-2 rounded-full" :class="[DOT[status], hasChanges && 'ring-2 ring-blue-500 ring-offset-1']" />
    {{ label }}
  </span>
</template>
