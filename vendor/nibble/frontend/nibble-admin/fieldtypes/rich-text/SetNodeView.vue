<script setup lang="ts">
import { NodeViewWrapper, nodeViewProps } from '@tiptap/vue-3'
import { computed, ref } from 'vue'
import ReplicatorSet from '../components/ReplicatorSet.vue'
import type { PublishSetGroup } from '../types'

export type SetNodeStorage = {
  groups: PublishSetGroup[]
  fieldPathPrefix: string
  metaPathPrefix: string
  readOnly: boolean
  canAdd: () => boolean
  duplicate: (id: string) => void
  insertAfter: (pos: number, handle: string) => void
}

const props = defineProps(nodeViewProps)
const storage = computed(() => (props.editor.storage as unknown as Record<string, SetNodeStorage>).set!)
const sets = computed(() => storage.value.groups.flatMap((group) => group.sets))
const index = computed(() => props.editor.state.doc.resolve(props.getPos() ?? 0).index(0))
const values = computed(() => (props.node.attrs.values ?? {}) as Record<string, unknown> & { type: string })
const collapsed = ref(false)
</script>

<template>
  <NodeViewWrapper class="nibble-set my-4" contenteditable="false" data-drag-handle>
    <ReplicatorSet
      :row="{ ...values, _id: node.attrs.id, type: values.type, enabled: node.attrs.enabled }"
      :set="sets.find((set) => set.handle === values.type)"
      :groups="storage.groups"
      :collapsed="collapsed"
      :read-only="storage.readOnly"
      :can-add="storage.canAdd()"
      :field-path-prefix="`${storage.fieldPathPrefix}.${index}.attrs.values`"
      :meta-path-prefix="`${storage.metaPathPrefix}.existing.${node.attrs.id}`"
      @toggle="collapsed = !collapsed"
      @duplicate="storage.duplicate(node.attrs.id)"
      @remove="deleteNode()"
      @enable="(enabled) => updateAttributes({ enabled })"
      @add-below="(handle) => storage.insertAfter((getPos() ?? 0) + node.nodeSize, handle)"
    />
  </NodeViewWrapper>
</template>
