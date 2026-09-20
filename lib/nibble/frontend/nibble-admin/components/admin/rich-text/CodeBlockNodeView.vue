<script setup lang="ts">
import { NodeViewContent, NodeViewWrapper, nodeViewProps } from '@tiptap/vue-3'
import { computed } from 'vue'
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select'
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
      class="absolute top-2 right-2 opacity-0 transition-opacity group-hover/code:opacity-100 focus-within:opacity-100 has-[[data-state=open]]:opacity-100"
      contenteditable="false"
      @mousedown.stop
    >
      <Select v-model="language">
        <SelectTrigger
          size="sm"
          aria-label="Code language"
          class="h-7 w-auto gap-1 rounded-md border-white/10 bg-white/5 from-transparent to-transparent px-2 font-mono text-xs text-gray-300 shadow-none hover:text-white dark:border-white/10 dark:from-transparent dark:to-transparent dark:text-gray-300"
        >
          <SelectValue placeholder="auto" />
        </SelectTrigger>
        <SelectContent class="font-mono text-xs">
          <SelectItem v-for="name in codeLanguages" :key="name" :value="name">{{ name }}</SelectItem>
        </SelectContent>
      </Select>
    </div>
    <pre><NodeViewContent as="code" :class="language && `language-${language}`" /></pre>
  </NodeViewWrapper>
</template>
