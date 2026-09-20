import { onBeforeUnmount, reactive, ref } from 'vue'

export type Shortcut = { combo: string; handler: (event: KeyboardEvent) => void; when?: () => boolean; label?: string }

// Every shortcut currently registered by a mounted component, for the "?" dialog to list.
const registry = reactive<Shortcut[]>([])
export const shortcutsDialogOpen = ref(false)

function isMac() {
  return typeof navigator !== 'undefined' && /Mac|iPhone|iPod|iPad/.test(navigator.platform ?? navigator.userAgent)
}

// "mod+s" -> Meta on Mac, Ctrl elsewhere. "shift"/"alt" are only checked when named in the combo —
// there is no bare, unmodified shortcut in this registry that a held Shift/Alt should block.
// Exported for direct unit testing (pure logic — see lib/__tests__/shortcuts.test.ts).
export function parseCombo(combo: string) {
  const parts = combo.toLowerCase().split('+')
  const key = parts.pop()!
  return { key, mod: parts.includes('mod'), shift: parts.includes('shift'), alt: parts.includes('alt') }
}

export function matchesCombo(event: KeyboardEvent, combo: string) {
  const { key, mod, shift, alt } = parseCombo(combo)
  const modPressed = isMac() ? event.metaKey : event.ctrlKey
  if (mod !== modPressed) return false
  if (shift && !event.shiftKey) return false
  if (alt && !event.altKey) return false
  return event.key.toLowerCase() === key
}

// Duck-typed rather than `instanceof HTMLElement`: the tests run without a DOM (this module has no
// other browser dependency at import time), and instanceof would be unreliable across realms anyway
// (an event target from an iframe has a different HTMLElement constructor than this window's).
export function isTypingTarget(target: EventTarget | null) {
  const el = target as { tagName?: string; isContentEditable?: boolean } | null
  return el?.tagName === 'INPUT' || el?.tagName === 'TEXTAREA' || el?.isContentEditable === true
}

// Whether `shortcut` should fire for `event`: the combo matches, it isn't a bare key typed into a
// text field (mod+ combos like ⌘S are always safe — they're never plain text input), and its `when`
// guard (if any) currently allows it. Exported so the whole decision is unit-testable without a live
// keydown dispatch.
export function shouldFire(event: KeyboardEvent, shortcut: Shortcut): boolean {
  if (!matchesCombo(event, shortcut.combo)) return false
  if (!parseCombo(shortcut.combo).mod && isTypingTarget(event.target)) return false
  if (shortcut.when && !shortcut.when()) return false
  return true
}

let listening = false
function ensureListener() {
  if (listening || typeof window === 'undefined') return
  listening = true
  window.addEventListener('keydown', (event) => {
    for (const shortcut of registry) {
      if (!shouldFire(event, shortcut)) continue
      event.preventDefault()
      shortcut.handler(event)
      return
    }
  })
}

// Registers `combo` while the calling component is mounted. `when`, if given, is checked fresh on
// every keypress (e.g. only fire ⌘S while the form isn't already saving).
export function useShortcut(
  combo: string,
  handler: (event: KeyboardEvent) => void,
  options: { when?: () => boolean; label?: string } = {},
) {
  ensureListener()
  const shortcut: Shortcut = { combo, handler, when: options.when, label: options.label }
  registry.push(shortcut)
  onBeforeUnmount(() => {
    const index = registry.indexOf(shortcut)
    if (index !== -1) registry.splice(index, 1)
  })
}

// Read by ShortcutsDialog. Shortcuts without a label (internal ones) aren't shown.
export function useRegisteredShortcuts() {
  return registry
}

const KEY_LABELS: Record<string, string> = { enter: '↵', s: 'S', k: 'K', '?': '?' }

export function formatCombo(combo: string): string {
  const { key, mod, shift, alt } = parseCombo(combo)
  const parts: string[] = []
  if (mod) parts.push(isMac() ? '⌘' : 'Ctrl')
  if (alt) parts.push(isMac() ? '⌥' : 'Alt')
  if (shift) parts.push(isMac() ? '⇧' : 'Shift')
  parts.push(KEY_LABELS[key] ?? key.toUpperCase())
  return parts.join(isMac() ? '' : '+')
}
