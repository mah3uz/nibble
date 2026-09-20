import { afterEach, describe, expect, test, vi } from 'vitest'
import { isTypingTarget, matchesCombo, parseCombo, shouldFire } from '../shortcuts'

// Plain objects shaped like the bits of KeyboardEvent/EventTarget these functions actually read —
// this suite runs without a DOM (see the module comment on isTypingTarget for why that's fine).
function keydown(
  key: string,
  modifiers: Partial<{ metaKey: boolean; ctrlKey: boolean; shiftKey: boolean; altKey: boolean }> = {},
  target: { tagName?: string; isContentEditable?: boolean } | null = null,
) {
  return {
    key,
    metaKey: false,
    ctrlKey: false,
    shiftKey: false,
    altKey: false,
    target,
    ...modifiers,
  } as unknown as KeyboardEvent
}

afterEach(() => {
  vi.unstubAllGlobals()
})

describe('parseCombo', () => {
  test('splits modifiers from the key', () => {
    expect(parseCombo('mod+s')).toEqual({ key: 's', mod: true, shift: false, alt: false })
    expect(parseCombo('mod+shift+s')).toEqual({ key: 's', mod: true, shift: true, alt: false })
    expect(parseCombo('?')).toEqual({ key: '?', mod: false, shift: false, alt: false })
  })
})

describe('matchesCombo', () => {
  test('"mod" means Meta on Mac', () => {
    vi.stubGlobal('navigator', { platform: 'MacIntel', userAgent: 'Macintosh' })
    expect(matchesCombo(keydown('s', { metaKey: true }), 'mod+s')).toBe(true)
    expect(matchesCombo(keydown('s', { ctrlKey: true }), 'mod+s')).toBe(false)
  })

  test('"mod" means Ctrl elsewhere', () => {
    vi.stubGlobal('navigator', { platform: 'Win32', userAgent: 'Windows' })
    expect(matchesCombo(keydown('s', { ctrlKey: true }), 'mod+s')).toBe(true)
    expect(matchesCombo(keydown('s', { metaKey: true }), 'mod+s')).toBe(false)
  })

  test('a bare key matches with no modifiers held', () => {
    vi.stubGlobal('navigator', { platform: 'Win32', userAgent: 'Windows' })
    expect(matchesCombo(keydown('?'), '?')).toBe(true)
  })

  test('a combo with no mod is refused when mod is held, so it never fights ⌘S-style shortcuts', () => {
    vi.stubGlobal('navigator', { platform: 'Win32', userAgent: 'Windows' })
    expect(matchesCombo(keydown('s', { ctrlKey: true }), 's')).toBe(false)
  })
})

function target(shape: { tagName?: string; isContentEditable?: boolean }) {
  return shape as unknown as EventTarget
}

describe('isTypingTarget', () => {
  test('true for text inputs and textareas, false otherwise', () => {
    expect(isTypingTarget(target({ tagName: 'TEXTAREA' }))).toBe(true)
    expect(isTypingTarget(target({ tagName: 'INPUT' }))).toBe(true)
    expect(isTypingTarget(target({ tagName: 'BUTTON' }))).toBe(false)
    expect(isTypingTarget(target({ tagName: 'DIV', isContentEditable: true }))).toBe(true)
    expect(isTypingTarget(null)).toBe(false)
  })
})

describe('shouldFire', () => {
  test('a "?"-style shortcut is not triggered while typing in a textarea', () => {
    vi.stubGlobal('navigator', { platform: 'Win32', userAgent: 'Windows' })
    const shortcut = { combo: '?', handler: vi.fn() }
    expect(shouldFire(keydown('?'), shortcut)).toBe(true)
    expect(shouldFire(keydown('?', {}, { tagName: 'TEXTAREA' }), shortcut)).toBe(false)
  })

  test('a mod+ shortcut still fires while typing in a textarea', () => {
    vi.stubGlobal('navigator', { platform: 'Win32', userAgent: 'Windows' })
    const event = keydown('s', { ctrlKey: true }, { tagName: 'TEXTAREA' })
    expect(shouldFire(event, { combo: 'mod+s', handler: vi.fn() })).toBe(true)
  })

  test('a false `when` refuses the shortcut even if the combo matches', () => {
    vi.stubGlobal('navigator', { platform: 'Win32', userAgent: 'Windows' })
    expect(shouldFire(keydown('?'), { combo: '?', handler: vi.fn(), when: () => false })).toBe(false)
  })
})
