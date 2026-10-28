import { describe, expect, it } from 'vitest'
import { withoutIdentity } from '../blocks'

describe('withoutIdentity', () => {
  it("keeps a block's row id and type off its view, where the id would land on the root element as an HTML id", () => {
    const block = { id: 'row-7', type: 'cta', heading: 'Join', queries: { latest: [] } }

    expect(withoutIdentity(block)).toEqual({ heading: 'Join', queries: { latest: [] } })
  })
})
