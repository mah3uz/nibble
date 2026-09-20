<script setup lang="ts">
import { router } from '@inertiajs/vue3'
import { ref, shallowRef } from 'vue'
import PageHeader from '@/components/admin/page/PageHeader.vue'
import { Button } from '@/components/ui/button'
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select'
import { registerCoreFieldtypes } from '@/nibble-admin/fieldtypes/core'
import type { PublishBlueprint } from '@/nibble-admin/fieldtypes/types'
import PublishContainer from '@/nibble-admin/publish/PublishContainer.vue'

const props = defineProps<{
  blueprints: { key: string; title: string }[]
  current: string
  blueprint: PublishBlueprint
  values: Record<string, unknown>
  meta: Record<string, unknown>
}>()

registerCoreFieldtypes()

const values = ref(props.values)
const meta = ref(props.meta)
const visibleValues = shallowRef<Record<string, unknown>>({})
const errors = ref<Record<string, string[]>>({})
const result = ref<{ processed: unknown; augmented: unknown } | null>(null)
const status = ref<'idle' | 'invalid' | 'valid'>('idle')

async function validate() {
  const csrf = document.querySelector<HTMLMetaElement>('meta[name=csrf-token]')?.content ?? ''
  const response = await fetch('/admin/nibble/playground/validate', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', Accept: 'application/json', 'X-CSRF-Token': csrf },
    body: JSON.stringify({ blueprint: props.current, values: visibleValues.value }),
  })
  const body = (await response.json()) as { errors: Record<string, string[]>; processed?: unknown; augmented?: unknown }
  errors.value = body.errors
  status.value = Object.keys(body.errors).length ? 'invalid' : 'valid'
  result.value = status.value === 'valid' ? { processed: body.processed, augmented: body.augmented } : null
}
</script>

<template>
  <div class="space-y-6">
    <PageHeader title="Fieldtype playground">
      <template #actions>
        <Select
          :model-value="current"
          @update:model-value="(key) => router.get('/admin/nibble/playground', { blueprint: String(key) })"
        >
          <SelectTrigger class="w-72" aria-label="Blueprint"><SelectValue /></SelectTrigger>
          <SelectContent>
            <SelectItem v-for="option in blueprints" :key="option.key" :value="option.key">{{
              option.title
            }}</SelectItem>
          </SelectContent>
        </Select>
        <Button type="button" data-testid="validate" @click="validate">Validate</Button>
      </template>
    </PageHeader>

    <p
      v-if="status !== 'idle'"
      data-testid="status"
      :class="status === 'valid' ? 'text-emerald-700' : 'text-destructive'"
    >
      {{ status === 'valid' ? 'Valid' : `${Object.keys(errors).length} field(s) have errors` }}
    </p>

    <PublishContainer
      :key="current"
      v-model="values"
      v-model:meta="meta"
      :blueprint="blueprint"
      :errors="errors"
      @update:visible-values="(visible) => (visibleValues = visible)"
    />

    <div v-if="result" class="grid gap-4 lg:grid-cols-2">
      <section>
        <h2 class="mb-2 text-sm font-medium">Stored</h2>
        <pre data-testid="processed" class="max-h-96 overflow-auto rounded-lg bg-gray-900 p-4 text-xs text-gray-100">{{
          JSON.stringify(result.processed, null, 2)
        }}</pre>
      </section>
      <section>
        <h2 class="mb-2 text-sm font-medium">Public (augmented)</h2>
        <pre data-testid="augmented" class="max-h-96 overflow-auto rounded-lg bg-gray-900 p-4 text-xs text-gray-100">{{
          JSON.stringify(result.augmented, null, 2)
        }}</pre>
      </section>
    </div>
  </div>
</template>
