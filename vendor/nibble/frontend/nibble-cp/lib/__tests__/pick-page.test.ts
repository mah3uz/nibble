import { describe, expect, it } from 'vitest'
import { pickCpPage } from '../pick-page'

const app = {
  '../pages/cp/entries/Edit.vue': 'nibble-edit',
  '../pages/cp/media/Index.vue': 'nibble-media',
}

describe('pickCpPage', () => {
  it('loads Nibble page when the site has not overridden it', () => {
    expect(pickCpPage('cp/media/Index', {}, app)).toBe('nibble-media')
  })

  it('prefers the site copy so a screen can be replaced without editing ours', () => {
    const site = { '/repo/site/cp/pages/cp/entries/Edit.vue': 'site-edit' }

    expect(pickCpPage('cp/entries/Edit', site, app)).toBe('site-edit')
    expect(pickCpPage('cp/media/Index', site, app)).toBe('nibble-media')
  })

  it('matches on the full path so a nested name cannot be shadowed by a shorter one', () => {
    const site = { '/repo/site/cp/pages/Edit.vue': 'wrong' }

    expect(pickCpPage('cp/entries/Edit', site, app)).toBe('nibble-edit')
  })

  it('returns nothing for a page neither side defines, so the caller can fail loudly', () => {
    expect(pickCpPage('cp/nope', {}, app)).toBeUndefined()
  })
})
