<script setup lang="ts">
import { computed } from 'vue'
import { fieldtypeEmits, fieldtypeProps, useFieldtype } from '../useFieldtype'
import RelationshipInput from './RelationshipInput.vue'

const props = defineProps(fieldtypeProps)
const emit = defineEmits(fieldtypeEmits)
const { update, updateMeta, isReadOnly, expose } = useFieldtype(emit, props)
defineExpose(expose)

const scope = computed(() => ({ taxonomies: props.config.taxonomies ?? [] }))
</script>

<template>
  <RelationshipInput
    :id="id"
    type="term"
    :value="value"
    :meta="meta"
    :scope="scope"
    :max-items="Number(config.max_items) || 0"
    :read-only="isReadOnly"
    :label="(config.placeholder as string) || 'Choose…'"
    @update="update"
    @update-meta="updateMeta"
  />
</template>
