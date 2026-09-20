import { defineAsyncComponent, markRaw, type Component } from 'vue'

type Loader = Component | (() => Promise<{ default: Component }>)

const fieldtypes = new Map<string, Component>()
const indexFieldtypes = new Map<string, Component>()

function normalize(loader: Loader): Component {
  return markRaw(
    typeof loader === 'function' ? defineAsyncComponent(loader as () => Promise<{ default: Component }>) : loader,
  )
}

export function registerFieldtype(handle: string, loader: Loader) {
  fieldtypes.set(handle, normalize(loader))
}

export function registerIndexFieldtype(handle: string, loader: Loader) {
  indexFieldtypes.set(handle, normalize(loader))
}

export function resolveFieldtype(component: string) {
  return fieldtypes.get(component) ?? null
}

export function resolveIndexFieldtype(component: string) {
  return indexFieldtypes.get(component) ?? null
}

export function registeredFieldtypes() {
  return [...fieldtypes.keys()].sort()
}
