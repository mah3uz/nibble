<script setup lang="ts">
import { ChevronDownIcon } from '@lucide/vue'
import { NodeViewContent, NodeViewWrapper, nodeViewProps } from '@tiptap/vue-3'
import { computed } from 'vue'
import { codeLanguages } from '@/fieldtypes/rich-text/extensions'

const props = defineProps(nodeViewProps)

// The theme highlights the published page off this class, so an unset language leaves it plain there.
const language = computed({
  get: () => String(props.node.attrs.language ?? ''),
  set: (value: string) => props.updateAttributes({ language: value || null }),
})
</script>

<template>
  <!-- The wrapper cannot be the pre: Tiptap sets white-space: normal on it, which unwraps the code. -->
  <NodeViewWrapper class="group/code relative">
    <div
      class="absolute top-2 right-2 opacity-0 transition-opacity group-hover/code:opacity-100 focus-within:opacity-100"
      contenteditable="false"
    >
      <select
        v-model="language"
        aria-label="Code language"
        class="h-6 cursor-pointer appearance-none rounded-sm border border-gray-700 bg-gray-800 py-0 pr-6 pl-2 font-mono text-xs text-gray-300 outline-none hover:text-white focus-visible:focus-outline"
        @mousedown.stop
      >
        <option class="bg-[Canvas] text-[CanvasText]" value="">plain text</option>
        <option v-for="name in codeLanguages" :key="name" class="bg-[Canvas] text-[CanvasText]" :value="name">
          {{ name }}
        </option>
      </select>
      <ChevronDownIcon class="pointer-events-none absolute top-1/2 right-1.5 size-3 -translate-y-1/2 text-gray-400" />
    </div>
    <pre><NodeViewContent as="code" :class="language && `language-${language}`" /></pre>
  </NodeViewWrapper>
</template>
