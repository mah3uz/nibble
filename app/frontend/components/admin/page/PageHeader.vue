<script setup lang="ts">
import AdminIcon from '@/components/admin/icons/AdminIcon.vue'
import { useBreadcrumbs, type Breadcrumb } from '@/lib/breadcrumbs'

const props = defineProps<{ title: string; icon?: string; breadcrumbs?: Breadcrumb[] }>()
if (props.breadcrumbs?.length) useBreadcrumbs(props.breadcrumbs)
</script>

<template>
  <header
    class="relative mb-0! flex min-h-10 flex-wrap items-center justify-between gap-4 py-6 max-md:pb-8 md:box-content md:py-8"
  >
    <div class="flex min-w-0 items-center gap-2.5 md:flex-1">
      <AdminIcon v-if="icon" :name="icon" class="size-5 shrink-0 text-gray-500" />
      <h1 class="truncate st-text-legibility text-[25px] leading-[1.25] font-medium antialiased">{{ title }}</h1>
      <slot name="meta" />
    </div>
    <div class="flex flex-wrap items-center gap-2 sm:gap-3"><slot name="actions" /></div>
  </header>
</template>
