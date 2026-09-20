<script setup lang="ts">
import { ref, watch } from 'vue'
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs'
import type { PublishTab } from '../fieldtypes/types'
import { useContainer } from './context'
import PublishSections from './PublishSections.vue'

const props = defineProps<{ tabs: PublishTab[] }>()
const active = ref(props.tabs[0]?.handle ?? '')
const { errors } = useContainer()

watch(
  () => props.tabs,
  (tabs) => {
    if (!tabs.some((tab) => tab.handle === active.value)) active.value = tabs[0]?.handle ?? ''
  },
)

function tabHasError(tab: PublishTab) {
  const handles = tab.sections.flatMap((section) => section.fields.map((field) => field.handle))
  return Object.keys(errors.value).some((path) =>
    handles.some((handle) => path === handle || path.startsWith(`${handle}.`)),
  )
}
</script>

<template>
  <Tabs v-model="active">
    <TabsList v-if="tabs.length > 1" class="-mt-2 mb-6">
      <TabsTrigger v-for="tab in tabs" :key="tab.handle" :value="tab.handle" class="gap-1.5">
        {{ tab.display }}
        <span
          v-if="tabHasError(tab)"
          class="inline-block size-1.5 rounded-full bg-destructive"
          aria-label="Has errors"
        />
      </TabsTrigger>
    </TabsList>
    <TabsContent v-for="tab in tabs" :key="tab.handle" :value="tab.handle">
      <PublishSections :sections="tab.sections" />
    </TabsContent>
  </Tabs>
</template>
