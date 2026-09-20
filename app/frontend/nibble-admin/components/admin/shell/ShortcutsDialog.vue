<script setup lang="ts">
import { computed } from 'vue'
import { Dialog, DialogContent, DialogHeader, DialogTitle } from '@/components/ui/dialog'
import { formatCombo, shortcutsDialogOpen, useRegisteredShortcuts } from '@/lib/shortcuts'

const registered = useRegisteredShortcuts()
const shortcuts = computed(() => {
  const seen = new Map<string, string>()
  for (const s of registered) if (s.label && !seen.has(s.label)) seen.set(s.label, s.combo)
  return [...seen.entries()].map(([label, combo]) => ({ label, combo }))
})
</script>

<template>
  <Dialog v-model:open="shortcutsDialogOpen">
    <DialogContent>
      <DialogHeader><DialogTitle>Keyboard shortcuts</DialogTitle></DialogHeader>
      <ul class="divide-y text-sm">
        <li v-for="s in shortcuts" :key="s.label" class="flex items-center justify-between py-2">
          <span>{{ s.label }}</span>
          <kbd class="rounded-md border bg-muted px-2 py-1 font-mono text-xs">{{ formatCombo(s.combo) }}</kbd>
        </li>
        <li v-if="shortcuts.length === 0" class="py-2 text-muted-foreground">No shortcuts available on this page.</li>
      </ul>
    </DialogContent>
  </Dialog>
</template>
