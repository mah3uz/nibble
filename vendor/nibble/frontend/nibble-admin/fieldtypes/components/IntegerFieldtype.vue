<script setup lang="ts">
import { InputGroup, InputGroupAddon, InputGroupInput, InputGroupText } from '@/components/ui/input-group'
import { fieldtypeEmits, fieldtypeProps, useFieldtype } from '../useFieldtype'

const props = defineProps(fieldtypeProps)
const emit = defineEmits(fieldtypeEmits)
const { update, isReadOnly, expose } = useFieldtype(emit, props)
defineExpose(expose)

function onInput(raw: string | number) {
  const text = String(raw)
  update(text === '' || Number.isNaN(Number(text)) ? null : Math.trunc(Number(text)))
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
      inputmode="numeric"
      :model-value="value == null ? '' : String(value)"
      :min="config.min as number"
      :max="config.max as number"
      :step="(config.step as number) || 1"
      :placeholder="config.placeholder as string"
      :readonly="isReadOnly"
      @update:model-value="onInput"
    />
    <InputGroupAddon v-if="config.append" align="inline-end">
      <InputGroupText>{{ config.append }}</InputGroupText>
    </InputGroupAddon>
  </InputGroup>
</template>
