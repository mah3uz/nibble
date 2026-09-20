<script setup lang="ts">
import { computed, ref } from 'vue'
import { Button } from '@/components/ui/button'
import { InputGroup, InputGroupInput } from '@/components/ui/input-group'
import { fieldtypeEmits, fieldtypeProps, useFieldtype } from '../useFieldtype'

type SecretValue = { set?: boolean; ciphertext?: string; plain?: string; clear?: boolean } | null

const props = defineProps(fieldtypeProps)
const emit = defineEmits(fieldtypeEmits)
const { update, isReadOnly, expose } = useFieldtype(emit, props)
defineExpose(expose)

const value = computed(() => props.value as SecretValue)
const stored = computed(() => !!value.value?.ciphertext && !value.value.plain && !value.value.clear)
const replacing = ref(false)
const plain = ref('')

function onInput(raw: string | number) {
  plain.value = String(raw)
  update(plain.value ? { plain: plain.value } : { ciphertext: value.value?.ciphertext })
}

function clear() {
  plain.value = ''
  replacing.value = false
  update({ clear: true })
}
</script>

<template>
  <div class="flex items-center gap-2">
    <InputGroup class="flex-1">
      <InputGroupInput
        :id="id"
        :name="handle"
        type="password"
        autocomplete="off"
        :model-value="stored && !replacing ? '••••••••' : plain"
        :placeholder="(config.placeholder as string) || 'Not set'"
        :disabled="isReadOnly || (stored && !replacing)"
        @update:model-value="onInput"
        @focus="emit('focus')"
        @blur="emit('blur')"
      />
    </InputGroup>
    <template v-if="stored && !isReadOnly">
      <Button v-if="!replacing" type="button" variant="outline" size="sm" @click="replacing = true">Replace</Button>
      <Button type="button" variant="ghost" size="sm" @click="clear">Clear</Button>
    </template>
  </div>
</template>
