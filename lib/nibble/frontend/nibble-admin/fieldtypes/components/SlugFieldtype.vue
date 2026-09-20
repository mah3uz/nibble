<script setup lang="ts">
import { RefreshCw } from '@lucide/vue'
import { computed, onMounted, ref, watch } from 'vue'
import { InputGroup, InputGroupAddon, InputGroupButton, InputGroupInput } from '@/components/ui/input-group'
import { slugify } from '../../lib/slugify'
import { fieldtypeEmits, fieldtypeProps, useFieldtype } from '../useFieldtype'
import { useSiblings } from '../useSiblings'

const props = defineProps(fieldtypeProps)
const emit = defineEmits(fieldtypeEmits)
const { update, isReadOnly, expose } = useFieldtype(emit, props)
defineExpose(expose)

const siblings = useSiblings(props)
const separator = computed(() => (props.config.separator as string) || '-')
const source = computed(() => siblings.value[(props.config.from as string) || 'title'])
// Generation stops once the slug has a value of its own, so renaming the title never silently changes a URL.
const generating = ref(false)
onMounted(() => (generating.value = props.config.generate !== false && !props.value))

watch(source, (text) => {
  if (!generating.value || isReadOnly.value || typeof text !== 'string') return
  update(slugify(text, separator.value))
})

function onInput(raw: string | number) {
  generating.value = false
  update(String(raw))
}
</script>

<template>
  <InputGroup>
    <InputGroupInput
      :id="id"
      :name="handle"
      :model-value="(value as string) ?? ''"
      :disabled="isReadOnly"
      class="font-mono text-sm"
      @update:model-value="onInput"
    />
    <InputGroupAddon v-if="config.show_regenerate && !isReadOnly" align="inline-end">
      <InputGroupButton
        type="button"
        size="icon-xs"
        aria-label="Regenerate from source"
        title="Regenerate from source"
        @click="typeof source === 'string' && update(slugify(source, separator))"
      >
        <RefreshCw />
      </InputGroupButton>
    </InputGroupAddon>
  </InputGroup>
</template>
