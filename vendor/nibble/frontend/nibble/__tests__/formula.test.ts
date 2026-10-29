import { describe, expect, it, vi } from 'vitest'
import cases from '../../../../../test/fixtures/files/nibble_formulas.json'
import { calculate, evaluateFormula, formatCalculation, FormulaError, parseFormula } from '../formula'
import type { NibbleFormField } from '../types'

vi.mock('@inertiajs/vue3', () => ({ router: {} }))
vi.mock('../composables', async () => {
  const { ref } = await import('vue')
  return { useLocale: () => ref('en') }
})
vi.mock('vue', async (original) => ({
  ...(await original<typeof import('vue')>()),
  onMounted: () => {},
  onBeforeUnmount: () => {},
}))

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

describe('useNibbleForm calculations', () => {
  it('recalculates the total as the visitor changes a quantity, and drops an input once its condition hides it', async () => {
    const { useNibbleForm } = await import('../useNibbleForm')
    const fields = [
      field('quantity', { type: 'integer' }),
      field('delivery', { type: 'toggle' }),
      field('postcode_fee', {
        type: 'integer',
        conditions: { show: true, match: 'all', rules: [{ field: 'delivery', operator: 'equals', value: 'true' }] },
      }),
      field('total', { type: 'calculation', formula: '{quantity} * 400 + {postcode_fee}', decimals: 2, prepend: '$' }),
    ]
    const form = useNibbleForm({
      handle: 'quote',
      title: null,
      action: '/forms/quote',
      honeypot: null,
      captcha: null,
      fields,
      sections: null,
      success: {},
      result: null,
    })
    const total = fields[3]!

    expect(form.calculatedText(total)).toBe('$0.00')
    form.values.quantity = '3'
    form.values.delivery = true
    form.values.postcode_fee = 50
    expect(form.calculated(total)).toBe(1250)
    expect(form.calculatedText(total)).toBe('$1,250.00')
    form.values.delivery = false
    expect(form.calculated(total)).toBe(1200)
  })
})
