<script setup lang="ts">
import { ChevronDown } from '@lucide/vue'
import { Button } from '@/components/ui/button'
import { Collapsible, CollapsibleContent, CollapsibleTrigger } from '@/components/ui/collapsible'
import type { PublishSection } from '../fieldtypes/types'
import PublishFields from './PublishFields.vue'

defineProps<{ sections: PublishSection[] }>()
</script>

<template>
  <Collapsible
    v-for="(section, index) in sections"
    :key="index"
    :default-open="!section.collapsed"
    :disabled="!section.collapsible"
    class="@container/panel relative mb-6 w-full rounded-2xl bg-gray-150 p-1.75 has-[>header]:pt-0 max-[600px]:p-1.25 dark:bg-gray-950/35 dark:inset-shadow-2xs dark:inset-shadow-black"
  >
    <header v-if="section.display || section.collapsible" class="flex items-center justify-between px-4.5 py-3">
      <div>
        <h3
          class="flex items-center gap-2 text-sm font-medium tracking-tight text-gray-700 antialiased dark:text-white"
        >
          {{ section.display }}
        </h3>
        <p v-if="section.instructions" class="text-sm text-gray-600/90 dark:text-gray-400">
          {{ section.instructions }}
        </p>
      </div>
      <CollapsibleTrigger v-if="section.collapsible" as-child>
        <Button
          variant="ghost"
          size="icon-xs"
          class="-my-2 rounded-xl data-[state=open]:[&_svg]:rotate-180"
          aria-label="Toggle section"
        >
          <ChevronDown />
        </Button>
      </CollapsibleTrigger>
    </header>
    <CollapsibleContent>
      <div
        class="dark:ring-x-0 dark:ring-b-0 space-y-2 rounded-xl bg-white px-4 py-5 shadow-ui-md ring ring-gray-200 sm:px-4.5 dark:bg-gray-850 dark:ring-gray-700/80"
      >
        <PublishFields :fields="section.fields" />
      </div>
    </CollapsibleContent>
  </Collapsible>
</template>
