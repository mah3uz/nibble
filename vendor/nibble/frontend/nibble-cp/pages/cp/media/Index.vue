<script setup lang="ts">
import { router, usePage } from '@inertiajs/vue3'
import { computed } from 'vue'
import type { BrowseResponse } from '@/components/cp/assets/api'
import AssetBrowser, { type BrowseParams } from '@/components/cp/assets/AssetBrowser.vue'
import { useBreadcrumbs } from '@/lib/breadcrumbs'

const props = defineProps<BrowseResponse>()
useBreadcrumbs([{ label: 'Assets', url: '/cp/media' }])

const data = computed<BrowseResponse>(() => ({ ...props }))
const DATA_PROPS = ['listing', 'folders', 'folder', 'folder_options', 'asset_id', 'can']

function query() {
  return Object.fromEntries(new URLSearchParams(usePage().url.split('?')[1] ?? ''))
}

function visit(params: BrowseParams, only: string[]) {
  const next = Object.fromEntries(
    Object.entries({ ...query(), ...params }).filter(([, value]) => value !== null && value !== ''),
  )
  router.get('/cp/media', next, { preserveState: true, preserveScroll: true, replace: true, only })
}
</script>

<template>
  <AssetBrowser
    :data="data"
    :editing-id="asset_id"
    @navigate="(params) => visit({ ...params, asset: null }, DATA_PROPS)"
    @update:editing-id="(id) => visit({ asset: id }, ['asset_id'])"
    @changed="router.reload({ only: DATA_PROPS })"
  />
</template>
