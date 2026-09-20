import { ref } from 'vue'

// Shared across GlobalHeader (trigger button), AdminLayout (⌘K shortcut) and CommandPalette itself —
// same pattern as shortcutsDialogOpen in lib/shortcuts.ts.
export const commandPaletteOpen = ref(false)
