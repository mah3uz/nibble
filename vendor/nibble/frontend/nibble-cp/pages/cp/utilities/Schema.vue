<script setup lang="ts">
import { Link } from '@inertiajs/vue3'
import CpIcon from '@/components/cp/icons/CpIcon.vue'
import CpPanel from '@/components/cp/page/CpPanel.vue'
import PanelFact from '@/components/cp/page/PanelFact.vue'
import PageHeader from '@/components/cp/page/PageHeader.vue'
import { Button } from '@/components/ui/button'
import { useBreadcrumbs } from '@/lib/breadcrumbs'

type Item = { handle: string; title: string | null }

defineProps<{
  schema: {
    digest: string
    theme: string | null
    collections: Item[]
    taxonomies: Item[]
    globals: Item[]
    navigations: Item[]
  }
  checks: { source: string; message: string }[]
}>()

const groups = ['collections', 'taxonomies', 'globals', 'navigations'] as const
const LABELS = {
  collections: 'Collections',
  taxonomies: 'Taxonomies',
  globals: 'Global sets',
  navigations: 'Navigation',
}

useBreadcrumbs([{ label: 'Utilities', url: '/cp/utilities' }, { label: 'Schema' }])
</script>

<template>
  <div>
    <PageHeader
      title="Schema"
      icon="blueprints"
      :breadcrumbs="[{ label: 'Utilities', url: '/cp/utilities' }, { label: 'Schema' }]"
    >
      <template #actions>
        <Button variant="outline" as-child><Link href="/cp/blueprints">Browse blueprints</Link></Button>
      </template>
    </PageHeader>

    <CpPanel title="nibble:check" :flush="checks.length > 0">
      <template #actions>
        <PanelFact label="Theme" :value="schema.theme ?? 'none'" />
        <PanelFact label="Digest" :value="schema.digest" />
      </template>
      <p v-if="!checks.length" class="flex items-center gap-2 text-sm text-gray-700 dark:text-gray-300">
        <span class="size-2 rounded-full bg-green-500" aria-hidden="true" />
        No problems. Every blueprint, fieldset, form and the theme check out.
      </p>
      <ul v-else>
        <li
          v-for="problem in checks"
          :key="`${problem.source}-${problem.message}`"
          class="flex gap-3 border-b border-gray-100 px-4.5 py-3 last:border-0 dark:border-gray-800"
        >
          <span class="mt-1.5 size-2 shrink-0 rounded-full bg-red-500" aria-hidden="true" />
          <span>
            <span class="block font-mono text-xs text-gray-500">{{ problem.source }}</span>
            <span class="text-gray-800 dark:text-gray-200">{{ problem.message }}</span>
          </span>
        </li>
      </ul>
    </CpPanel>

    <div class="mb-6 grid gap-6 md:grid-cols-2">
      <CpPanel v-for="group in groups" :key="group" :title="LABELS[group]" fill>
        <p v-if="!schema[group].length" class="text-sm text-gray-500">None defined.</p>
        <ul v-else class="flex flex-wrap gap-2">
          <li
            v-for="item in schema[group]"
            :key="item.handle"
            class="flex items-center gap-1.5 rounded-md border border-gray-300 px-2 py-0.5 text-xs dark:border-gray-700"
          >
            <CpIcon :name="group === 'navigations' ? 'navigation' : group" class="size-3.5 text-gray-500" />
            {{ item.title ?? item.handle }}
          </li>
        </ul>
      </CpPanel>
    </div>
  </div>
</template>
