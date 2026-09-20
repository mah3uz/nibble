<script setup lang="ts">
import { computed, ref, watch } from 'vue'
import { Textarea } from '@/components/ui/textarea'
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
const limit = computed(() => Number(props.config.character_limit) || 0)
</script>

<template>
  <div class="space-y-1">
    <Textarea
      :id="id"
      :name="handle"
      :model-value="text"
      :rows="(config.rows as number) || 3"
      :placeholder="config.placeholder as string"
      :readonly="isReadOnly"
      @update:model-value="(raw) => updateDebounced((text = String(raw)))"
      @focus="emit('focus')"
      @blur="emit('blur')"
    />
    <p
      v-if="limit && !isReadOnly"
      class="text-xs"
      :class="text.length > limit ? 'text-destructive' : 'text-muted-foreground'"
    >
      {{ text.length }}/{{ limit }}
    </p>
  </div>
</template>
