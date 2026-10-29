import { describe, expect, it } from 'vitest'
import cases from '../../../../../test/fixtures/files/nibble_formulas.json'
import { calculate, evaluateFormula, formatCalculation, FormulaError, parseFormula } from '../formula'
import type { NibbleFormField } from '../types'

type Case = {
  description: string
  formula: string
  values?: Record<string, unknown>
  decimals?: number
  references?: string[]
  result?: number | null
  error?: boolean
}

// Shared with Nibble::Forms::FormulaTest: the visitor's running total must be the value the server stores.
describe('formula (shared cases with Nibble::Forms::Formula)', () => {
  for (const example of cases as Case[]) {
    it(example.description, () => {
      if (example.error) {
        expect(() => parseFormula(example.formula)).toThrow(FormulaError)
        return
      }
      const formula = parseFormula(example.formula)
      expect(evaluateFormula(formula, example.values ?? {}, example.decimals)).toEqual(example.result)
      if (example.references) expect(formula.references).toEqual(example.references)
    })
  }
})

const field = (handle: string, extra: Record<string, unknown>) =>
  ({ handle, display: handle, instructions: null, required: false, ...extra }) as NibbleFormField

describe('calculate', () => {
  it('feeds one calculation into another, and leaves a loop blank instead of hanging the page', () => {
    const fields = [
      field('quantity', { type: 'integer' }),
      field('subtotal', { type: 'calculation', formula: '{quantity} * 10' }),
      field('total', { type: 'calculation', formula: '{subtotal} * 1.1', decimals: 2 }),
      field('loop', { type: 'calculation', formula: '{again} + 1' }),
      field('again', { type: 'calculation', formula: '{loop} + 1' }),
    ]

    const results = calculate(fields, { quantity: '3' }, () => true)

    expect(results.get('total')).toBe(33)
    expect(results.get('loop')).toBe(2)
  })

  it('counts a field hidden by its conditions as 0, as the server does', () => {
    const fields = [
      field('quantity', { type: 'integer' }),
      field('shipping', { type: 'integer' }),
      field('total', { type: 'calculation', formula: '{quantity} * 10 + {shipping}' }),
    ]

    const results = calculate(fields, { quantity: 2, shipping: 50 }, (one) => one.handle !== 'shipping')

    expect(results.get('total')).toBe(20)
  })
})

describe('formatCalculation', () => {
  it('shows the decimals asked for, grouped, between the prepend and append', () => {
    expect(formatCalculation({ decimals: 2, prepend: '$' }, 1250, 'en')).toBe('$1,250.00')
    expect(formatCalculation({ append: ' kg' }, 12.5, 'en')).toBe('12.5 kg')
    expect(formatCalculation({ prepend: '$' }, null, 'en')).toBe('')
  })
})
