// Must stay identical to Nibble::Conditions (lib/nibble/conditions.rb): the server re-checks what the editor saw.
export const KEYS = [
  'if',
  'if_any',
  'show_when',
  'show_when_any',
  'unless',
  'unless_any',
  'hide_when',
  'hide_when_any',
] as const
const OPERATORS = ['equals', 'not', 'contains', 'contains_any', '===', '!==', '>', '>=', '<', '<=', 'custom']
const ALIASES: Record<string, string> = {
  is: 'equals',
  '==': 'equals',
  isnt: 'not',
  '!=': 'not',
  includes: 'contains',
  includes_any: 'contains_any',
}
const NUMERIC = ['>', '>=', '<', '<=']
const ROOT_PREFIX = /^\$?root\./
const EMPTY = Symbol('empty')

type Values = Record<string, unknown>
type Condition = { field: string; operator: string; value: string }
export type CustomCondition = (args: {
  params: string[]
  target: unknown
  targetHandle: string | null
  values: Values
  rootValues: Values
  path: string | null
}) => boolean

const custom = new Map<string, CustomCondition>()

export function registerCondition(name: string, callback: CustomCondition) {
  custom.set(name, callback)
}

export function unregisterCondition(name: string) {
  custom.delete(name)
}

export type VisibilityOptions = { values: Values; rootValues?: Values; path?: string | null; prefix?: string | null }

export function isVisible(
  fieldConfig: Record<string, unknown>,
  { values, rootValues, path = null, prefix = null }: VisibilityOptions,
) {
  const key = KEYS.find((candidate) => jsTruthy(fieldConfig[candidate]))
  if (!key) return true

  const context = { values, rootValues: rootValues ?? values, path }
  const conditions = fieldConfig[key]
  let passed: boolean
  if (typeof conditions === 'string') {
    passed = passesCustom(prepareCustom(conditions, null), context)
  } else {
    const results = parse(conditions as Record<string, unknown>, prefix).map((condition) =>
      evaluate(condition, context),
    )
    passed = key.includes('any') ? results.some(Boolean) : results.every(Boolean)
  }
  return key.startsWith('unless') || key.startsWith('hide_when') ? !passed : passed
}

export function parse(conditions: Record<string, unknown>, prefix: string | null = null): Condition[] {
  return Object.entries(conditions ?? {}).flatMap(([handle, rhs]) =>
    (Array.isArray(rhs) ? rhs : [rhs]).map((value) => splitRhs(handle, value, prefix)),
  )
}

function splitRhs(handle: string, rhs: unknown, prefix: string | null): Condition {
  const string = rhs === null || rhs === undefined ? 'null' : rhs === '' ? 'empty' : String(rhs)
  const all = [...OPERATORS, ...Object.keys(ALIASES)]
  const matching = all.filter((operator) => new RegExp(`^${escapeRegex(operator)} [^=]`).test(string))
  const last = matching.at(-1) ?? '=='
  const operator = ALIASES[last] ?? last
  const value = matching.reduce((remaining, op) => remaining.replace(new RegExp(`^${escapeRegex(op)} *`), ''), string)
  const scoped =
    handle.startsWith('$root.') || handle.startsWith('root.') || handle.startsWith('$parent.') || !prefix
      ? handle
      : `${prefix}${handle}`
  return { field: scoped, operator, value }
}

type Context = { values: Values; rootValues: Values; path: string | null }

function evaluate(condition: Condition, context: Context): boolean {
  if (condition.operator === 'custom') return passesCustom(prepareCustom(condition.value, condition.field), context)

  const operator = jsOperator(condition.operator)
  const raw = fieldValue(condition.field, context)
  if (operator === 'includes') return includes(raw, condition.value)
  if (operator === 'includes_any') return includesAny(prepareLhs(raw, operator), condition.value)
  return compare(prepareLhs(raw, operator), operator, prepareRhs(condition.value, operator))
}

function jsOperator(operator: string) {
  switch (operator) {
    case '':
    case 'is':
    case 'equals':
      return '=='
    case 'isnt':
    case 'not':
      return '!='
    case 'includes':
    case 'contains':
      return 'includes'
    case 'includes_any':
    case 'contains_any':
      return 'includes_any'
    default:
      return operator
  }
}

function prepareLhs(value: unknown, operator: string): unknown {
  if (NUMERIC.includes(operator)) return jsNumber(value)
  if (typeof value === 'string' && value === '') return null
  return typeof value === 'string' ? value.trim() : (value ?? null)
}

function prepareRhs(value: string, operator: string): unknown {
  if (value === 'null') return null
  if (value === 'true') return true
  if (value === 'false') return false
  if (NUMERIC.includes(operator)) return jsNumber(value)
  return value === 'empty' ? EMPTY : value.trim()
}

function compare(lhs: unknown, operator: string, rhs: unknown): boolean {
  if (rhs === EMPTY) {
    lhs = isEmpty(lhs)
    rhs = true
  }
  if (lhs !== null && typeof lhs === 'object') return false

  switch (operator) {
    case '==':
      return looseEqual(lhs, rhs)
    case '!=':
      return !looseEqual(lhs, rhs)
    case '===':
      return strictEqual(lhs, rhs)
    case '!==':
      return !strictEqual(lhs, rhs)
    case '>':
      return (lhs as number) > (rhs as number)
    case '>=':
      return (lhs as number) >= (rhs as number)
    case '<':
      return (lhs as number) < (rhs as number)
    case '<=':
      return (lhs as number) <= (rhs as number)
    default:
      return false
  }
}

function includes(value: unknown, needle: string) {
  if (Array.isArray(value)) return value.includes(needle)
  if (value !== null && typeof value === 'object') return false
  if (value === null || value === undefined || value === false || value === 0 || value === '')
    return ''.includes(needle)
  return String(value).includes(needle)
}

function includesAny(value: unknown, needles: string) {
  const options = needles.split(',').map((option) => option.trim())
  if (Array.isArray(value)) return value.some((item) => options.includes(item as string))
  return new RegExp(options.join('|')).test(jsString(value))
}

function jsString(value: unknown) {
  if (value === null || value === undefined) return 'null'
  return typeof value === 'string' ? JSON.stringify(value) : String(value)
}

function jsTruthy(value: unknown) {
  return !(value === null || value === undefined || value === false || value === '' || value === 0)
}

function isEmpty(value: unknown) {
  if (value === null || value === undefined) return true
  if (typeof value === 'number' || typeof value === 'boolean') return false
  if (Array.isArray(value) || typeof value === 'string') return value.length === 0
  if (typeof value === 'object') return Object.keys(value).length === 0
  return false
}

// Mirrors the Ruby port's explicit rules rather than relying on JS `==` coercion quirks.
function looseEqual(lhs: unknown, rhs: unknown) {
  if (lhs === null || lhs === undefined || rhs === null || rhs === undefined) {
    return (lhs === null || lhs === undefined) && (rhs === null || rhs === undefined)
  }
  if (typeof lhs === typeof rhs) return lhs === rhs
  const left = jsNumber(lhs)
  const right = jsNumber(rhs)
  return !Number.isNaN(left) && !Number.isNaN(right) && left === right
}

function strictEqual(lhs: unknown, rhs: unknown) {
  return typeof lhs === typeof rhs && lhs === rhs
}

function jsNumber(value: unknown) {
  if (value === null || value === undefined || value === false) return 0
  if (value === true) return 1
  if (typeof value === 'number') return value
  if (typeof value === 'string') {
    const trimmed = value.trim()
    if (trimmed === '') return 0
    return /^[-+]?(\d+\.?\d*|\.\d+)(e[-+]?\d+)?$/i.test(trimmed) ? Number(trimmed) : Number.NaN
  }
  return Number.NaN
}

function fieldValue(handle: string, context: Context) {
  if (handle.startsWith('$parent.')) handle = resolveParent(context.path, handle)
  return ROOT_PREFIX.test(handle)
    ? dig(context.rootValues, handle.replace(ROOT_PREFIX, ''))
    : dig(context.values, handle)
}

function dig(values: unknown, dotted: string) {
  return dotted.split('.').reduce<unknown>((current, key) => {
    if (Array.isArray(current)) return /^\d+$/.test(key) ? current[Number(key)] : undefined
    if (current !== null && typeof current === 'object') return (current as Values)[key]
    return undefined
  }, values)
}

const PARENT_PATH = /^(.*?[^.]+)((?:\.[0-9]+)*)\.[^.]*$/

export function resolveParent(currentPath: string | null, pathWithParent: string) {
  const parentPath = (path: string, removeCurrent = false) => {
    if (removeCurrent || /\.[0-9]+$/.test(path)) path = path.replace(PARENT_PATH, '$1')
    return path.includes('.') ? path.replace(PARENT_PATH, '$1$2') : ''
  }
  let parent = parentPath(currentPath ?? '', true)
  let remaining = pathWithParent.replace(/^\$parent\./, '')
  while (remaining.startsWith('$parent.')) {
    parent = parentPath(parent)
    remaining = remaining.replace(/^\$parent\./, '')
  }
  return `$root.${parent ? `${parent}.${remaining}` : remaining}`
}

function prepareCustom(value: string, targetField: string | null) {
  const [name, params = ''] = value.replace(/^custom /, '').split(/:(.*)/s)
  return {
    name: name!,
    params: params
      .split(',')
      .map((param) => param.trim())
      .filter(Boolean),
    targetField,
  }
}

function passesCustom(condition: { name: string; params: string[]; targetField: string | null }, context: Context) {
  const callback = custom.get(condition.name)
  if (!callback) throw new Error(`field condition '${condition.name}' isn't registered`)
  const target = condition.targetField ? fieldValue(condition.targetField, context) : null
  return Boolean(
    callback({
      params: condition.params,
      target,
      targetHandle: condition.targetField,
      values: context.values,
      rootValues: context.rootValues,
      path: context.path,
    }),
  )
}

function escapeRegex(value: string) {
  return value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')
}
