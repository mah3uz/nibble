<script setup lang="ts">
import { Link } from '@inertiajs/vue3'
import AdminIcon from '@/components/admin/icons/AdminIcon.vue'
import PageHeader from '@/components/admin/page/PageHeader.vue'
import type { PublishBlueprint } from '@/nibble-admin/fieldtypes/types'
import FieldOutline from './FieldOutline.vue'

defineProps<{ label: string; source: string; blueprint: PublishBlueprint }>()
</script>

<template>
  <div class="mx-auto max-w-5xl">
    <Link
      href="/admin/blueprints"
      class="relative z-10 -mb-6 flex w-fit items-center gap-1 pt-6 text-sm text-gray-600 hover:text-gray-900 dark:text-gray-400 dark:hover:text-white"
    >
      <AdminIcon name="chevron-left" class="size-4" />Blueprints
    </Link>
    <PageHeader
      :title="label"
      icon="blueprints"
      :breadcrumbs="[{ label: 'Blueprints', url: '/admin/blueprints' }, { label }]"
    />
    <p class="mb-6 text-sm text-gray-600 dark:text-gray-400">
      Defined in <code class="rounded bg-gray-100 px-1 dark:bg-gray-800">{{ source }}</code>
    </p>

    <section
      v-for="tab in blueprint.tabs"
      :key="tab.handle"
      class="relative mb-6 w-full rounded-2xl bg-gray-150 p-1.75 pt-0 dark:bg-gray-950/35 dark:inset-shadow-2xs dark:inset-shadow-black"
    >
      <header class="px-4.5 py-3">
        <h2 class="text-sm font-medium tracking-tight text-gray-700 dark:text-white">{{ tab.display }}</h2>
      </header>
      <div
        class="space-y-4 rounded-xl bg-white px-4 py-5 shadow-ui-md ring ring-gray-200 sm:px-4.5 dark:bg-gray-850 dark:ring-gray-700/80"
      >
        <div v-for="(section, index) in tab.sections" :key="index" class="space-y-2">
          <h3 v-if="section.display" class="text-sm text-gray-600 dark:text-gray-400">{{ section.display }}</h3>
          <FieldOutline v-for="field in section.fields" :key="field.handle" :field="field" />
        </div>
      </div>
    </section>
  </div>
</template>
