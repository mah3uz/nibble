type Container = Record<string, unknown> | unknown[]

export function joinPath(...parts: (string | number | null | undefined)[]) {
  return parts.filter((part) => part !== null && part !== undefined && part !== '').join('.')
}

export function getPath(source: unknown, path: string | null | undefined): unknown {
  if (!path) return source
  return path.split('.').reduce<unknown>((current, key) => {
    if (Array.isArray(current)) return /^\d+$/.test(key) ? current[Number(key)] : undefined
    if (current !== null && typeof current === 'object') return (current as Record<string, unknown>)[key]
    return undefined
  }, source)
}

// Copies only the containers along the path, so untouched branches keep their identity for Vue.
export function setPath<T extends Container>(source: T, path: string, value: unknown): T {
  const [key, ...rest] = path.split('.')
  const isIndex = /^\d+$/.test(key!)
  const copy = (Array.isArray(source) ? [...source] : { ...source }) as Record<string, unknown>
  const index = isIndex && Array.isArray(source) ? Number(key) : key!
  if (rest.length === 0) {
    copy[index as string] = value
  } else {
    const child = copy[index as string]
    const next = child !== null && typeof child === 'object' ? (child as Container) : /^\d+$/.test(rest[0]!) ? [] : {}
    copy[index as string] = setPath(next, rest.join('.'), value)
  }
  return copy as T
}

export function withoutKey<T extends Record<string, unknown>>(source: T, key: string): T {
  return Object.fromEntries(Object.entries(source).filter(([candidate]) => candidate !== key)) as T
}

export function omitPaths<T extends Record<string, unknown>>(source: T, paths: string[]): T {
  return [...paths]
    .sort((a, b) => b.split('.').length - a.split('.').length)
    .reduce((result, path) => {
      const parentPath = path.split('.').slice(0, -1).join('.')
      const key = path.split('.').at(-1)!
      const parent = getPath(result, parentPath)
      if (parent === null || typeof parent !== 'object' || Array.isArray(parent) || !(key in parent)) return result
      const kept = withoutKey(parent as Record<string, unknown>, key)
      return parentPath ? setPath(result, parentPath, kept) : (kept as T)
    }, source)
}
