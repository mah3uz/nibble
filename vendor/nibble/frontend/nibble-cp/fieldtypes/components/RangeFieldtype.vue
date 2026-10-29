<script setup lang="ts">
import { X } from '@lucide/vue'
import { computed } from 'vue'
import { Button } from '@/components/ui/button'
import { Slider } from '@/components/ui/slider'
import { fieldtypeEmits, fieldtypeProps, useFieldtype } from '../useFieldtype'

const props = defineProps(fieldtypeProps)
const emit = defineEmits(fieldtypeEmits)
const { update, isReadOnly, expose } = useFieldtype(emit, props)
defineExpose(expose)

const min = computed(() => (props.config.min as number | undefined) ?? 0)
const max = computed(() => (props.config.max as number | undefined) ?? 100)
const step = computed(() => (props.config.step as number | undefined) || 1)
const set = computed(() => typeof props.value === 'number')
const current = computed(() => (set.value ? (props.value as number) : min.value))
const required = computed(
  () => props.config.required === true || (props.config.validate as string[] | undefined)?.includes('required'),
)
const label = computed(() => (props.config.display as string | undefined) || props.handle)

function onUpdate(next: number[] | undefined) {
  if (next?.[0] !== undefined) update(next[0])
}
</script>

<template>
  <div class="flex items-center gap-3">
    <Slider
      :id="id"
      :name="handle"
      :model-value="[current]"
      :min="min"
      :max="max"
      :step="step"
      :disabled="isReadOnly"
      :thumb-label="label"
      :class="{ 'opacity-60': !set }"
      @update:model-value="onUpdate"
    />
    <output
      :for="id"
      class="min-w-12 text-right text-sm whitespace-nowrap tabular-nums"
      :class="set ? 'text-gray-700 dark:text-gray-300' : 'text-gray-500 dark:text-gray-400'"
    >
      {{ set ? `${config.prepend ?? ''}${current}${config.append ?? ''}` : 'Not set' }}
    </output>
    <Button
      v-if="set && !required && !isReadOnly"
      type="button"
      variant="subtle"
      size="icon-sm"
      :aria-label="`Clear ${label}`"
      @click="update(null)"
      ><X
    /></Button>
  </div>
</template>
