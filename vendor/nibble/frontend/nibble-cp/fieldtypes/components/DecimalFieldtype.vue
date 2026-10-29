<script setup lang="ts">
import { computed, ref } from 'vue'
import { InputGroup, InputGroupAddon, InputGroupInput, InputGroupText } from '@/components/ui/input-group'
import { decimalText } from '../display'
import { fieldtypeEmits, fieldtypeProps, useFieldtype } from '../useFieldtype'

const props = defineProps(fieldtypeProps)
const emit = defineEmits(fieldtypeEmits)
const { update, isReadOnly, expose } = useFieldtype(emit, props)
defineExpose(expose)

const step = computed(
  () => (props.config.step as number) || 10 ** -((props.config.decimals as number | undefined) ?? 2),
)

const typed = ref<string | null>(null)
const shown = computed(() => typed.value ?? decimalText(props.value, props.config.decimals as number | undefined))

function onInput(raw: string | number) {
  const text = String(raw)
  typed.value = text
  update(text === '' || Number.isNaN(Number(text)) ? null : Number(text))
}
</script>

<template>
  <InputGroup :class="{ 'border-dashed': isReadOnly }">
    <InputGroupAddon v-if="config.prepend">
      <InputGroupText>{{ config.prepend }}</InputGroupText>
    </InputGroupAddon>
    <InputGroupInput
      :id="id"
      :name="handle"
      type="number"
      inputmode="decimal"
      :model-value="shown"
      :min="config.min as number"
      :max="config.max as number"
      :step="step"
      :placeholder="config.placeholder as string"
      :readonly="isReadOnly"
      @update:model-value="onInput"
      @blur="typed = null"
    />
    <InputGroupAddon v-if="config.append" align="inline-end">
      <InputGroupText>{{ config.append }}</InputGroupText>
    </InputGroupAddon>
  </InputGroup>
</template>
