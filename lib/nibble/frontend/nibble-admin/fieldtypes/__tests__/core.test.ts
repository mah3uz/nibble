import { describe, expect, it } from 'vitest'
import allHandles from '../../../../../../test/fixtures/files/nibble_fieldtypes.json'
import { coreFieldtypeHandles, registerCoreFieldtypes } from '../core'
import { registeredFieldtypes, resolveFieldtype } from '../registry'

// Public-form fieldtypes are rendered by themes, never edited in the CP.
const FORM_ONLY = ['files']
const handles = allHandles.filter((handle) => !FORM_ONLY.includes(handle))

describe('core fieldtypes (shared list with Nibble::Fieldtypes::CORE)', () => {
  it('every CP-editable server fieldtype has a CP component, and nothing extra ships', () => {
    expect([...coreFieldtypeHandles].sort()).toEqual(handles)
  })

  it('registering makes each component resolvable by the handle the server sends', () => {
    registerCoreFieldtypes()
    expect(registeredFieldtypes()).toEqual(handles)
    for (const handle of handles) expect(resolveFieldtype(handle)).not.toBeNull()
  })
})
