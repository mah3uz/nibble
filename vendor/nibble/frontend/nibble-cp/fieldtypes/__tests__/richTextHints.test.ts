import { describe, expect, it } from 'vitest'
import { hintExtensions } from '../rich-text/extensions'

const summary = (config: Record<string, unknown>) => hintExtensions(config).map((ext) => [ext.name, ext.options])

describe('rich text placeholder and character limit', () => {
  it('shows the field placeholder while the editor is empty', () => {
    expect(summary({ placeholder: 'Write here' })[0]).toEqual([
      'placeholder',
      expect.objectContaining({ placeholder: 'Write here' }),
    ])
  })

  it('counts and limits characters only when the field sets a limit', () => {
    expect(summary({}).map(([name]) => name)).toEqual(['placeholder'])
    expect(summary({ character_limit: 120 })[1]).toEqual(['characterCount', expect.objectContaining({ limit: 120 })])
  })
})
