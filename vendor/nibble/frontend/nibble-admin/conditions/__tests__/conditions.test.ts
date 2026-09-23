import { afterEach, describe, expect, it } from 'vitest'
import cases from '../../../../../../test/fixtures/files/nibble_conditions.json'
import { isVisible, registerCondition, unregisterCondition } from '..'

type Case = {
  description: string
  config: Record<string, unknown>
  values: Record<string, unknown>
  root_values?: Record<string, unknown>
  path?: string
  prefix?: string
  visible: boolean
}

describe('isVisible (shared with Nibble::Conditions)', () => {
  for (const example of cases as Case[]) {
    it(example.description, () => {
      const visible = isVisible(example.config, {
        values: example.values,
        rootValues: example.root_values,
        path: example.path ?? null,
        prefix: example.prefix ?? null,
      })
      expect(visible).toBe(example.visible)
    })
  }
})

describe('custom conditions', () => {
  afterEach(() => {
    unregisterCondition('longer_than')
    unregisterCondition('never')
  })

  it('receive params and the target value', () => {
    registerCondition('longer_than', ({ params, target }) => String(target).length > Number(params[0]))
    expect(isVisible({ if: { title: 'custom longer_than:3' } }, { values: { title: 'Hello' } })).toBe(true)
    expect(isVisible({ if: { title: 'custom longer_than:10' } }, { values: { title: 'Hello' } })).toBe(false)
  })

  it('are inverted by unless even without a target, like the server', () => {
    registerCondition('never', () => false)
    expect(isVisible({ unless: 'custom never' }, { values: {} })).toBe(true)
  })

  it('fail loud when unregistered', () => {
    expect(() => isVisible({ if: 'custom missing' }, { values: {} })).toThrow("'missing' isn't registered")
  })
})
