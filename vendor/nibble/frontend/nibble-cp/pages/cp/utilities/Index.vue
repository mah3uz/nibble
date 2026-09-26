<script setup lang="ts">
import { Link } from '@inertiajs/vue3'
import CpIcon from '@/components/cp/icons/CpIcon.vue'
import CpPanel from '@/components/cp/page/CpPanel.vue'
import PageHeader from '@/components/cp/page/PageHeader.vue'
import { useBreadcrumbs } from '@/lib/breadcrumbs'

defineProps<{ utilities: { key: string; title: string; description: string; icon: string; url: string }[] }>()

useBreadcrumbs([{ label: 'Utilities' }])
</script>

<template>
  <div>
    <PageHeader title="Utilities" icon="utilities" />
    <CpPanel>
      <div class="flex flex-wrap">
        <Link
          v-for="utility in utilities"
          :key="utility.key"
          :href="utility.url"
          class="group w-full items-start rounded-md px-2 py-3 hover:bg-gray-100 md:flex lg:w-1/2 lg:p-4 dark:hover:bg-gray-800"
        >
          <CpIcon :name="utility.icon" class="me-4 mt-1 mb-2 size-6 text-gray-400" />
          <span class="flex-1 md:me-6">
            <span class="mb-0.5 block text-base font-medium text-gray-925 antialiased dark:text-white">{{
              utility.title
            }}</span>
            <span class="block text-sm tracking-tight text-pretty text-gray-600 dark:text-gray-400">{{
              utility.description
            }}</span>
          </span>
        </Link>
      </div>
    </CpPanel>
  </div>
</template>
