import { expect, test } from 'vitest'
import { buildQuery } from '../buildQuery'

test('drops only what the listing renders identically without', () => {
  expect(buildQuery({ q: '', sort: null, page: '1' })).toEqual({})
})

test('keeps a direction and page size even when they look like defaults', () => {
  expect(buildQuery({ sort: 'title', dir: 'asc', per_page: '25' })).toEqual({
    sort: 'title',
    dir: 'asc',
    per_page: '25',
  })
})

test('keeps a non-default page, sort and per_page', () => {
  expect(buildQuery({ q: '', sort: 'title', dir: 'desc', page: '3', per_page: '50' })).toEqual({
    sort: 'title',
    dir: 'desc',
    page: '3',
    per_page: '50',
  })
})

test('keeps a search term and drops an empty filter alongside it', () => {
  expect(buildQuery({ q: 'dental', status: '', category: '3' })).toEqual({ q: 'dental', category: '3' })
})

test("preserves a param it doesn't recognise, e.g. a filter a caller no longer declares", () => {
  expect(buildQuery({ q: 'dental', legacy_filter: 'x' })).toEqual({ q: 'dental', legacy_filter: 'x' })
})

test('keeps a multi-select filter as an array, and drops it once empty', () => {
  expect(buildQuery({ category: ['1', '2'] })).toEqual({ category: ['1', '2'] })
  expect(buildQuery({ category: [] })).toEqual({})
})
