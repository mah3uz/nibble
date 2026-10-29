import { createSSRApp } from 'vue'
import { renderToString } from 'vue/server-renderer'
import { describe, expect, it } from 'vitest'
import DecimalFieldtype from '../components/DecimalFieldtype.vue'
import RangeFieldtype from '../components/RangeFieldtype.vue'
import RatingFieldtype from '../components/RatingFieldtype.vue'
import { ratingAfterKey } from '../rating'

const render = (component: object, props: Record<string, unknown>) =>
  renderToString(createSSRApp(component, { handle: 'subject', id: 'subject', ...props }))

describe('decimal fieldtype', () => {
  it('steps by its scale so the browser accepts the places the server keeps', async () => {
    expect(await render(DecimalFieldtype, { value: 1.5, config: { decimals: 2 } })).toMatch(/step="0.01"/)
    expect(await render(DecimalFieldtype, { value: null, config: { decimals: 0 } })).toMatch(/step="1"/)
    expect(await render(DecimalFieldtype, { value: null, config: { decimals: 3, step: 0.5 } })).toMatch(/step="0.5"/)
  })
})

describe('range fieldtype', () => {
  it('shows the value beside the slider, and the minimum when nothing is chosen yet', async () => {
    const chosen = await render(RangeFieldtype, { value: 40, config: { append: '%' } })
    const empty = await render(RangeFieldtype, { value: null, config: { min: 10, max: 50 } })

    expect(chosen).toMatch(/<output[^>]*>\s*40%\s*<\/output>/)
    expect(empty).toMatch(/<output[^>]*>\s*10\s*<\/output>/)
    expect(chosen).toContain('role="slider"')
  })
})

describe('rating fieldtype', () => {
  it('is a radio group of stars, each named for a screen reader, with the chosen one checked', async () => {
    const html = await render(RatingFieldtype, { value: 3, config: { max: 5 } })

    expect(html).toContain('role="radiogroup"')
    expect(html.match(/role="radio"/g)).toHaveLength(5)
    expect(html).toContain('aria-label="3 of 5"')
    expect(html.match(/aria-checked="true"/g)).toHaveLength(1)
    expect(html).toMatch(/aria-checked="true"[^>]*tabindex="0"|tabindex="0"[^>]*aria-checked="true"/)
  })

  it('draws as many stars as its max, within 2 to 10', async () => {
    expect((await render(RatingFieldtype, { value: null, config: { max: 3 } })).match(/role="radio"/g)).toHaveLength(3)
    expect((await render(RatingFieldtype, { value: null, config: { max: 99 } })).match(/role="radio"/g)).toHaveLength(
      10,
    )
  })

  it('moves with the arrow keys within 1 to max, and clears on Backspace or Delete', () => {
    expect(ratingAfterKey('ArrowRight', 5, 5)).toBe(5)
    expect(ratingAfterKey('ArrowRight', 2, 5)).toBe(3)
    expect(ratingAfterKey('ArrowLeft', 1, 5)).toBe(1)
    expect(ratingAfterKey('ArrowDown', 4, 5)).toBe(3)
    expect([ratingAfterKey('Home', 4, 5), ratingAfterKey('End', 1, 5)]).toEqual([1, 5])
    expect([ratingAfterKey('Backspace', 4, 5), ratingAfterKey('Delete', 4, 5)]).toEqual([null, null])
    expect(ratingAfterKey('a', 4, 5)).toBeUndefined()
  })
})
