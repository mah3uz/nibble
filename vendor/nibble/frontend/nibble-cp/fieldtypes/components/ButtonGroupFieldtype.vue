<script setup lang="ts">
import { RadioGroupItem, RadioGroupRoot } from 'reka-ui'
import { computed } from 'vue'
import { toggleVariants } from '@/components/ui/toggle'
import { cn } from '@/lib/utils'
import { normalizeOptions, optionKey } from '../options'
import { fieldtypeEmits, fieldtypeProps, useFieldtype } from '../useFieldtype'

const props = defineProps(fieldtypeProps)
const emit = defineEmits(fieldtypeEmits)
const { update, isReadOnly, expose } = useFieldtype(emit, props)
defineExpose(expose)

const options = computed(() => normalizeOptions(props.meta, props.config))
const selectedKey = computed(() => (props.value == null ? undefined : optionKey(props.value)))

function select(key: unknown) {
  update(options.value.find((option) => optionKey(option.value) === key)?.value ?? null)
}

const itemClass = cn(
  toggleVariants({ variant: 'outline' }),
  'shrink-0 rounded-none border-s-0 px-3 first:rounded-s-lg first:border-s last:rounded-e-lg focus:z-10 focus-visible:z-10 data-[state=checked]:from-gray-100 data-[state=checked]:to-gray-100 data-[state=checked]:inset-shadow-sm/10 dark:data-[state=checked]:from-gray-950 dark:data-[state=checked]:to-gray-850 dark:data-[state=checked]:text-white',
)
</script>

<template>
  <RadioGroupRoot
    :id="id"
    :model-value="selectedKey"
    :disabled="isReadOnly"
    orientation="horizontal"
    loop
    class="flex w-fit max-w-full flex-row flex-wrap items-center"
    @update:model-value="select"
  >
    <RadioGroupItem
      v-for="option in options"
      :key="optionKey(option.value)"
      :value="optionKey(option.value)"
      :class="itemClass"
    >
      {{ option.label }}
    </RadioGroupItem>
  </RadioGroupRoot>
</template>
