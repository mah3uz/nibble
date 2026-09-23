<script setup lang="ts">
import { computed } from 'vue'
import type { DefineComponent } from 'vue'
import { find } from '@/lib/pick-page'

const props = defineProps<{ name: string }>()

const overrides = import.meta.glob<DefineComponent>('@site/cp/slots/*.vue', { eager: true, import: 'default' })
const override = computed(() => find(overrides, `/site/cp/slots/${props.name}.vue`))
</script>

<template>
  <component :is="override" v-if="override" />
  <slot v-else />
</template>
