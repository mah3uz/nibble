<script setup lang="ts">
import { refDebounced } from '@vueuse/core'
import { computed, ref, watch } from 'vue'
import { request } from '@/components/cp/assets/api'
import { useContainer } from '../../publish/context'
import { getPath } from '../../lib/paths'
import { fieldtypeEmits, fieldtypeProps, useFieldtype } from '../useFieldtype'

type Preview = { tags: Record<'head' | 'body_start' | 'body_end', string[]>; errors: Record<string, string> }

const props = defineProps(fieldtypeProps)
const emit = defineEmits(fieldtypeEmits)
const { expose } = useFieldtype(emit, props)
defineExpose(expose)

const { values } = useContainer()
const cardPath = computed(() => (props.fieldPathPrefix ?? '').split('.').slice(0, -1).join('.'))
const card = computed(() => JSON.stringify(getPath(values.value, cardPath.value) ?? {}))
const settled = refDebounced(card, 400)
const preview = ref<Preview | null>(null)
const failed = ref(false)

watch(
  settled,
  async (json) => {
    try {
      preview.value = await request<Preview>('POST', '/cp/nibble/analytics/preview', { card: JSON.parse(json) })
      failed.value = false
    } catch {
      failed.value = true
    }
  },
  { immediate: true },
)

const places = [
  ['head', 'In the head'],
  ['body_start', 'At the start of the body'],
  ['body_end', 'At the end of the body'],
] as const
const written = computed(() => places.filter(([place]) => (preview.value?.tags[place]?.length ?? 0) > 0))
const problems = computed(() => Object.values(preview.value?.errors ?? {}))
</script>

<template>
  <div :id="id" class="space-y-2 text-sm">
    <p v-if="failed" class="text-destructive">The tags could not be previewed.</p>
    <ul v-else-if="problems.length" class="space-y-1 text-destructive">
      <li v-for="problem in problems" :key="problem">{{ problem }}</li>
    </ul>
    <p v-else-if="preview && written.length === 0" class="text-muted-foreground">
      Nothing is written until the fields above are filled in.
    </p>
    <details v-if="written.length" class="group">
      <summary class="cursor-pointer text-muted-foreground select-none hover:text-foreground">
        Show the tags Nibble writes
      </summary>
      <div v-for="[place, label] in written" :key="place" class="mt-2">
        <p class="mb-1 text-xs text-muted-foreground">{{ label }}</p>
        <pre
          class="overflow-x-auto rounded-md bg-gray-50 p-3 font-mono text-xs break-all whitespace-pre-wrap dark:bg-gray-850"
        ><code>{{ preview!.tags[place].join('\n') }}</code></pre>
      </div>
    </details>
  </div>
</template>
