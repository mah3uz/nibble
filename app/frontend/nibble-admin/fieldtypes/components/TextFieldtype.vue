<script setup lang="ts">
import { computed, ref, watch } from 'vue'
import { InputGroup, InputGroupAddon, InputGroupInput, InputGroupText } from '@/components/ui/input-group'
import { fieldtypeEmits, fieldtypeProps, useFieldtype } from '../useFieldtype'

const props = defineProps(fieldtypeProps)
const emit = defineEmits(fieldtypeEmits)
const { updateDebounced, isReadOnly, expose } = useFieldtype(emit, props)
defineExpose(expose)

const text = ref(props.value == null ? '' : String(props.value))
watch(
  () => props.value,
  (value) => (text.value = value == null ? '' : String(value)),
)
function onInput(raw: string | number) {
  text.value = String(raw)
  updateDebounced(text.value)
}

const limit = computed(() => Number(props.config.character_limit) || 0)
const counterClass = computed(() => {
  const ratio = limit.value ? text.value.length / limit.value : 0
  return ratio > 1 ? 'text-destructive' : ratio >= 0.9 ? 'text-amber-600' : 'text-muted-foreground'
})
</script>

<template>
  <div class="space-y-1">
    <InputGroup :class="{ 'border-dashed': isReadOnly }">
      <InputGroupAddon v-if="config.prepend">
        <InputGroupText>{{ config.prepend }}</InputGroupText>
      </InputGroupAddon>
      <InputGroupInput
        :id="id"
        :name="handle"
        :type="(config.input_type as string) || 'text'"
        :model-value="text"
        :placeholder="config.placeholder as string"
        :autocomplete="(config.autocomplete as string) || undefined"
        :readonly="isReadOnly"
        @update:model-value="onInput"
        @focus="emit('focus')"
        @blur="emit('blur')"
      />
      <InputGroupAddon v-if="config.append" align="inline-end">
        <InputGroupText>{{ config.append }}</InputGroupText>
      </InputGroupAddon>
    </InputGroup>
    <p v-if="limit && !isReadOnly" class="text-xs" :class="counterClass">{{ text.length }}/{{ limit }}</p>
  </div>
</template>
