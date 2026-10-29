<script setup lang="ts">
import { Input } from '@/components/ui/input'
import { fieldtypeEmits, fieldtypeProps, useFieldtype } from '../useFieldtype'

const props = defineProps(fieldtypeProps)
const emit = defineEmits(fieldtypeEmits)
const { update, isReadOnly, expose } = useFieldtype(emit, props)
defineExpose(expose)
</script>

<template>
  <Input
    :id="id"
    :name="handle"
    type="time"
    class="w-auto"
    :model-value="typeof value === 'string' ? value : ''"
    :step="config.seconds ? 1 : 60"
    :min="(config.earliest as string) || undefined"
    :max="(config.latest as string) || undefined"
    :placeholder="config.placeholder as string"
    :readonly="isReadOnly"
    @update:model-value="(next) => update(next === '' ? null : String(next))"
    @focus="emit('focus')"
    @blur="emit('blur')"
  />
</template>
