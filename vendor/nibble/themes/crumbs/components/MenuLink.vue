<script setup lang="ts">
import type { NavigationItem } from '@nibble'
import { linkTag } from '../lib/links'

defineProps<{ item: Pick<NavigationItem, 'title' | 'new_tab' | 'current' | 'in_trail'> & { url: string } }>()
</script>

<template>
  <component
    :is="linkTag(item.url)"
    :href="item.url"
    :target="item.new_tab ? '_blank' : undefined"
    :rel="item.new_tab ? 'noopener' : undefined"
    :aria-current="item.current ? 'page' : item.in_trail ? 'true' : undefined"
  >
    {{ item.title }}<span v-if="item.new_tab" class="sr-only"> (opens in a new tab)</span>
  </component>
</template>
