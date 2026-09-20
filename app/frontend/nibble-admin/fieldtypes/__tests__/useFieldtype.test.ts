import { effectScope, nextTick, reactive } from 'vue'
import { afterEach, describe, expect, it, vi } from 'vitest'
import { clearFieldActions, registerFieldAction } from '../actions'
import { useFieldtype, type FieldtypeProps } from '../useFieldtype'

function setup(overrides: Partial<FieldtypeProps> = {}) {
  const emit = vi.fn()
  const props = reactive<FieldtypeProps>({
    value: 'Hello',
    config: { type: 'text', visibility: 'visible' } as FieldtypeProps['config'],
    handle: 'title',
    meta: {},
    readOnly: false,
    showFieldPreviews: false,
    ...overrides,
  })
  const scope = effectScope()
  const api = scope.run(() => useFieldtype(emit, props))!
  return { emit, props, api, scope }
}

describe('useFieldtype', () => {
  afterEach(() => {
    clearFieldActions()
    vi.useRealTimers()
  })

  it('emits value and meta updates for the container to store', () => {
    const { emit, api } = setup()
    api.update('New')
    api.updateMeta({ loaded: true })
    expect(emit).toHaveBeenCalledWith('update:value', 'New')
    expect(emit).toHaveBeenCalledWith('update:meta', { loaded: true })
  })

  it('debounces typing so the container is not flooded', async () => {
    vi.useFakeTimers()
    const { emit, api } = setup()
    api.updateDebounced('a')
    api.updateDebounced('ab')
    expect(emit).not.toHaveBeenCalledWith('update:value', 'ab')
    await vi.advanceTimersByTimeAsync(150)
    expect(emit).toHaveBeenCalledTimes(1)
    expect(emit).toHaveBeenCalledWith('update:value', 'ab')
  })

  it('is read-only when the form is, or when the field is read_only or computed', () => {
    expect(setup({ readOnly: true }).api.isReadOnly.value).toBe(true)
    expect(
      setup({ config: { type: 'text', visibility: 'computed' } as FieldtypeProps['config'] }).api.isReadOnly.value,
    ).toBe(true)
    expect(setup().api.isReadOnly.value).toBe(false)
  })

  it('builds bracketed names and path keys for nested fields', () => {
    const { api } = setup({ namePrefix: 'blocks[0]', fieldPathPrefix: 'blocks.0.title' })
    expect(api.name.value).toBe('blocks[0][title]')
    expect(api.fieldPathKeys.value).toEqual(['blocks', '0', 'title'])
  })

  it('reports a replicator preview only when previews are shown, using a custom definition if given', async () => {
    const { emit, api, props } = setup({ showFieldPreviews: true })
    expect(emit).toHaveBeenCalledWith('replicator-preview-updated', 'Hello')
    api.defineReplicatorPreview(() => `Preview: ${props.value}`)
    await nextTick()
    expect(emit).toHaveBeenLastCalledWith('replicator-preview-updated', 'Preview: Hello')
  })

  it('offers registered and internal field actions, hiding them when read-only', () => {
    registerFieldAction('text-fieldtype', {
      title: 'Uppercase',
      run: ({ value, update }) => update(String(value).toUpperCase()),
    })
    const { emit, api } = setup()
    api.defineFieldActions([{ title: 'Clear', run: ({ update }) => update(''), quick: true }])

    expect(api.fieldActions.value.map((action) => action.title)).toEqual(['Uppercase', 'Clear'])
    api.fieldActions.value[0]!.run()
    expect(emit).toHaveBeenCalledWith('update:value', 'HELLO')
    expect(setup({ readOnly: true }).api.fieldActions.value).toEqual([])
  })
})
