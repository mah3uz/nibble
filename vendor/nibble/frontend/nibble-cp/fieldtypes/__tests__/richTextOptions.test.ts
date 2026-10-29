import { describe, expect, it, vi } from 'vitest'
import { behaviourExtensions, isFloatingToolbar, ruleOptions } from '../rich-text/extensions'

const names = (config: Record<string, unknown>) => behaviourExtensions(config).map((ext) => ext.name)

describe('rich text editor options', () => {
  it('keeps the toolbar fixed unless the field asks for a floating one', () => {
    expect(isFloatingToolbar({})).toBe(false)
    expect(isFloatingToolbar({ toolbar_mode: 'fixed' })).toBe(false)
    expect(isFloatingToolbar({ toolbar_mode: 'floating' })).toBe(true)
  })

  it('curls quotes and dashes only with smart typography on', () => {
    expect(names({})).not.toContain('typography')
    expect(names({ smart_typography: true })).toContain('typography')
  })

  it('turns Markdown typing shortcuts off when input rules are disabled', () => {
    expect(ruleOptions({})).toEqual({ enableInputRules: true, enablePasteRules: true })
    expect(ruleOptions({ enable_input_rules: false, enable_paste_rules: false })).toEqual({
      enableInputRules: false,
      enablePasteRules: false,
    })
  })

  it('inserts a line break on Enter only in an inline field that asks for it', () => {
    expect(names({ inline_hard_breaks: true })).not.toContain('inlineHardBreaks')
    expect(names({ inline: true })).not.toContain('inlineHardBreaks')
    expect(names({ inline: true, inline_hard_breaks: true })).toContain('inlineHardBreaks')

    const hardBreak = behaviourExtensions({ inline: true, inline_hard_breaks: true }).find(
      (ext) => ext.name === 'inlineHardBreaks',
    )!
    const setHardBreak = vi.fn(() => true)
    const shortcuts = (hardBreak.config.addKeyboardShortcuts as () => Record<string, (a: unknown) => boolean>).call({})
    expect(shortcuts.Enter!({ editor: { commands: { setHardBreak } } })).toBe(true)
    expect(setHardBreak).toHaveBeenCalledOnce()
  })
})
