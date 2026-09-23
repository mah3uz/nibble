<script setup lang="ts">
import PublishForm from '@/components/admin/publish/PublishForm.vue'
import type { Can, DraftMeta, EditMeta, EditUrls, PublishBlueprint } from '@/components/admin/publish/context'
import type { Breadcrumb } from '@/lib/breadcrumbs'

defineProps<{
  title: string
  breadcrumbs: Breadcrumb[]
  resource_key: string
  blueprint: PublishBlueprint
  values: Record<string, unknown>
  field_meta: Record<string, unknown>
  meta: EditMeta
  draft: DraftMeta
  can: Can
  urls: EditUrls
}>()
</script>

<template>
  <div class="mx-auto max-w-5xl">
    <PublishForm
      :title="title"
      icon="globals"
      :breadcrumbs="breadcrumbs"
      :resource-key="resource_key"
      :blueprint="blueprint"
      :values="values"
      :field-meta="field_meta"
      :meta="meta"
      :draft="draft"
      :can="can"
      :urls="urls"
    />
  </div>
</template>
