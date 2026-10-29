import type { NibbleFormField } from './types'

// Must parse and count exactly as Nibble::Forms::Formula does: the server's value is the one stored.

export class FormulaError extends Error {}

type Node =
  | { kind: 'number'; value: number }
  | { kind: 'ref'; handle: string }
  | { kind: 'neg'; node: Node }
  | { kind: 'call'; name: string; args: Node[] }
  | { kind: 'op'; op: string; left: Node; right: Node }

type Token = { kind: 'number' | 'ref' | 'name' | 'op'; text: string }

export type Formula = { tree: Node; references: string[] }

const FUNCTIONS: Record<string, [number, number]> = { round: [1, 2], min: [2, 2], max: [2, 2] }
const NUMBER = /^-?\d+(?:\.\d+)?$/
const SPACE = /[ \t\r\n]*/y
const TOKENS: [Token['kind'], RegExp][] = [
  ['number', /\d+(?:\.\d+)?/y],
  ['ref', /\{([a-z][a-z0-9_]*)\}/y],
  ['name', /[a-z]+/y],
  ['op', /[-+*/(),]/y],
]
const MAX_DIGITS = 15

export function formulaNumber(raw: unknown): number {
  if (raw === true) return 1
  if (typeof raw === 'number') return raw
  if (typeof raw === 'string' && NUMBER.test(raw.trim())) return Number(raw.trim())
  return 0
}

export function roundTo(value: number, digits: number): number | null {
  const scale = 10 ** Math.min(Math.max(Math.trunc(digits), 0), MAX_DIGITS)
  const scaled = value * scale
  return Number.isFinite(scaled) ? (Math.sign(scaled) * Math.round(Math.abs(scaled))) / scale : null
}

function tokenize(source: string) {
  const tokens: Token[] = []
  let position = 0
  for (;;) {
    SPACE.lastIndex = position
    position += SPACE.exec(source)![0].length
    if (position >= source.length) return tokens
    const found = TOKENS.find(([, pattern]) => ((pattern.lastIndex = position), pattern.test(source)))
    if (!found) throw new FormulaError(`can't read '${source.slice(position, position + 10)}'`)
    const [kind, pattern] = found
    const match = source.slice(position, pattern.lastIndex)
    tokens.push({ kind, text: kind === 'ref' ? match.slice(1, -1) : match })
    position = pattern.lastIndex
  }
}

export function parseFormula(source: string): Formula {
  const tokens = tokenize(source)
  const references: string[] = []
  let position = 0

  const operator = () => (tokens[position]?.kind === 'op' ? tokens[position]!.text : null)
  const advance = () => tokens[position++]
  const accept = (op: string) => operator() === op && Boolean(advance())
  const expect = (op: string) => {
    if (!accept(op)) throw new FormulaError(`expected '${op}'`)
  }

  function expression(): Node {
    let node = term()
    while (operator() === '+' || operator() === '-')
      node = { kind: 'op', op: advance()!.text, left: node, right: term() }
    return node
  }

  function term(): Node {
    let node = unary()
    while (operator() === '*' || operator() === '/')
      node = { kind: 'op', op: advance()!.text, left: node, right: unary() }
    return node
  }

  function unary(): Node {
    return accept('-') ? { kind: 'neg', node: unary() } : primary()
  }

  function primary(): Node {
    const token = advance()
    switch (token?.kind) {
      case 'number':
        return { kind: 'number', value: Number(token.text) }
      case 'ref':
        references.push(token.text)
        return { kind: 'ref', handle: token.text }
      case 'name':
        return call(token.text)
      case 'op': {
        if (token.text !== '(') throw new FormulaError(`unexpected '${token.text}'`)
        const node = expression()
        expect(')')
        return node
      }
      default:
        throw new FormulaError('the formula ends too soon')
    }
  }

  function call(name: string): Node {
    const arity = FUNCTIONS[name]
    if (!arity) throw new FormulaError(`'${name}' isn't a function: use round, min or max`)
    expect('(')
    const args = [expression()]
    while (accept(',')) args.push(expression())
    expect(')')
    if (args.length < arity[0] || args.length > arity[1])
      throw new FormulaError(`${name} takes ${[...new Set(arity)].join(' or ')} values`)
    return { kind: 'call', name, args }
  }

  const tree = expression()
  if (tokens[position]) throw new FormulaError(`unexpected '${tokens[position]!.text}'`)
  return { tree, references: [...new Set(references)] }
}

const finite = (number: number | null) => (number !== null && Number.isFinite(number) ? number : null)

function value(node: Node, values: Record<string, unknown>): number | null {
  switch (node.kind) {
    case 'number':
      return node.value
    case 'ref':
      return formulaNumber(values[node.handle])
    case 'neg': {
      const inner = value(node.node, values)
      return inner === null ? null : -inner
    }
    case 'call': {
      const args = node.args.map((arg) => value(arg, values))
      if (args.includes(null)) return null
      const numbers = args as number[]
      if (node.name === 'round') return finite(roundTo(numbers[0]!, numbers[1] ?? 0))
      return finite(node.name === 'min' ? Math.min(...numbers) : Math.max(...numbers))
    }
    case 'op': {
      const left = value(node.left, values)
      const right = value(node.right, values)
      if (left === null || right === null || (node.op === '/' && right === 0)) return null
      if (node.op === '+') return finite(left + right)
      if (node.op === '-') return finite(left - right)
      return finite(node.op === '*' ? left * right : left / right)
    }
  }
}

export function evaluateFormula(formula: Formula, values: Record<string, unknown>, decimals?: number | null) {
  let result = value(formula.tree, values)
  if (result !== null && decimals !== undefined && decimals !== null) result = roundTo(result, decimals)
  return result === 0 ? 0 : result
}

export function calculate(
  fields: NibbleFormField[],
  values: Record<string, unknown>,
  isVisible: (field: NibbleFormField) => boolean,
) {
  const byHandle = new Map(fields.map((field) => [field.handle, field]))
  const results = new Map<string, number | null>()

  function result(field: NibbleFormField, path: string[]): number | null {
    if (results.has(field.handle)) return results.get(field.handle)!
    if (path.includes(field.handle) || !isVisible(field)) return null
    let number: number | null = null
    try {
      const formula = parseFormula(field.formula ?? '')
      const inputs = Object.fromEntries(
        formula.references.map((handle) => [handle, input(byHandle.get(handle), [...path, field.handle])]),
      )
      number = evaluateFormula(formula, inputs, field.decimals)
    } catch (error) {
      if (!(error instanceof FormulaError)) throw error
    }
    results.set(field.handle, number)
    return number
  }

  function input(field: NibbleFormField | undefined, path: string[]) {
    if (!field || !isVisible(field)) return null
    return field.type === 'calculation' ? result(field, path) : values[field.handle]
  }

  fields.filter((field) => field.type === 'calculation').forEach((field) => result(field, []))
  return results
}

export function formatCalculation(
  field: { decimals?: number; prepend?: string; append?: string },
  number: number | null,
  locale?: string,
) {
  if (number === null) return ''
  const digits =
    field.decimals === undefined
      ? { maximumFractionDigits: 10 }
      : { minimumFractionDigits: field.decimals, maximumFractionDigits: field.decimals }
  let format: Intl.NumberFormat
  try {
    format = new Intl.NumberFormat(locale, digits)
  } catch {
    format = new Intl.NumberFormat('en', digits)
  }
  return `${field.prepend ?? ''}${format.format(number)}${field.append ?? ''}`
}
