// Field values are plain JSON; this also unwraps Vue proxies, which structuredClone rejects.
export function clone<T>(value: T): T {
  return value === undefined ? value : (JSON.parse(JSON.stringify(value)) as T)
}
