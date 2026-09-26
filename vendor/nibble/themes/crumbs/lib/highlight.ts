import type { LanguageFn, Mode } from 'highlight.js'

function section(tag: string, attribute: string, subLanguage: string): Mode {
  return {
    begin: new RegExp(`^\\s*<${tag}\\b[^>]*${attribute}[^>]*>`),
    end: new RegExp(`^\\s*</${tag}>`),
    subLanguage,
    excludeBegin: true,
    excludeEnd: true,
  }
}

const vue: LanguageFn = (hljs) => ({
  name: 'Vue',
  subLanguage: 'xml',
  contains: [
    hljs.COMMENT('<!--', '-->', { relevance: 10 }),
    section('script', `\\blang=["']ts["']`, 'typescript'),
    section('script', '', 'javascript'),
    section('style', `\\blang=["']s[ac]ss["']`, 'scss'),
    section('style', '', 'css'),
  ],
})

const GRAMMARS = {
  arduino: () => import('highlight.js/lib/languages/arduino'),
  bash: () => import('highlight.js/lib/languages/bash'),
  c: () => import('highlight.js/lib/languages/c'),
  cpp: () => import('highlight.js/lib/languages/cpp'),
  csharp: () => import('highlight.js/lib/languages/csharp'),
  css: () => import('highlight.js/lib/languages/css'),
  diff: () => import('highlight.js/lib/languages/diff'),
  erb: () => import('highlight.js/lib/languages/erb'),
  go: () => import('highlight.js/lib/languages/go'),
  graphql: () => import('highlight.js/lib/languages/graphql'),
  ini: () => import('highlight.js/lib/languages/ini'),
  java: () => import('highlight.js/lib/languages/java'),
  javascript: () => import('highlight.js/lib/languages/javascript'),
  json: () => import('highlight.js/lib/languages/json'),
  kotlin: () => import('highlight.js/lib/languages/kotlin'),
  less: () => import('highlight.js/lib/languages/less'),
  lua: () => import('highlight.js/lib/languages/lua'),
  makefile: () => import('highlight.js/lib/languages/makefile'),
  markdown: () => import('highlight.js/lib/languages/markdown'),
  objectivec: () => import('highlight.js/lib/languages/objectivec'),
  perl: () => import('highlight.js/lib/languages/perl'),
  php: () => import('highlight.js/lib/languages/php'),
  'php-template': () => import('highlight.js/lib/languages/php-template'),
  plaintext: () => import('highlight.js/lib/languages/plaintext'),
  python: () => import('highlight.js/lib/languages/python'),
  'python-repl': () => import('highlight.js/lib/languages/python-repl'),
  r: () => import('highlight.js/lib/languages/r'),
  ruby: () => import('highlight.js/lib/languages/ruby'),
  rust: () => import('highlight.js/lib/languages/rust'),
  scss: () => import('highlight.js/lib/languages/scss'),
  shell: () => import('highlight.js/lib/languages/shell'),
  sql: () => import('highlight.js/lib/languages/sql'),
  swift: () => import('highlight.js/lib/languages/swift'),
  typescript: () => import('highlight.js/lib/languages/typescript'),
  vbnet: () => import('highlight.js/lib/languages/vbnet'),
  vue: async () => ({ default: vue }),
  wasm: () => import('highlight.js/lib/languages/wasm'),
  xml: () => import('highlight.js/lib/languages/xml'),
  yaml: () => import('highlight.js/lib/languages/yaml'),
}

const ALIASES: Record<string, Language> = {
  atom: 'xml',
  'c#': 'csharp',
  'c++': 'cpp',
  cc: 'cpp',
  cjs: 'javascript',
  console: 'shell',
  cs: 'csharp',
  cts: 'typescript',
  cxx: 'cpp',
  gemspec: 'ruby',
  golang: 'go',
  gql: 'graphql',
  gyp: 'python',
  'h++': 'cpp',
  h: 'c',
  hh: 'cpp',
  hpp: 'cpp',
  html: 'xml',
  hxx: 'cpp',
  ino: 'arduino',
  ipython: 'python',
  irb: 'ruby',
  js: 'javascript',
  json5: 'json',
  jsonc: 'json',
  jsp: 'java',
  jsx: 'javascript',
  kt: 'kotlin',
  ktm: 'kotlin',
  kts: 'kotlin',
  ktx: 'kotlin',
  mak: 'makefile',
  make: 'makefile',
  md: 'markdown',
  mjs: 'javascript',
  mk: 'makefile',
  mkd: 'markdown',
  mkdown: 'markdown',
  mm: 'objectivec',
  mts: 'typescript',
  'obj-c++': 'objectivec',
  'obj-c': 'objectivec',
  objc: 'objectivec',
  'objective-c++': 'objectivec',
  patch: 'diff',
  pl: 'perl',
  plist: 'xml',
  pluto: 'lua',
  pm: 'perl',
  podspec: 'ruby',
  py: 'python',
  pycon: 'python-repl',
  rb: 'ruby',
  rs: 'rust',
  rss: 'xml',
  sh: 'bash',
  shellsession: 'shell',
  svg: 'xml',
  text: 'plaintext',
  thor: 'ruby',
  toml: 'ini',
  ts: 'typescript',
  tsx: 'typescript',
  txt: 'plaintext',
  vb: 'vbnet',
  wsf: 'xml',
  xhtml: 'xml',
  xjb: 'xml',
  xsd: 'xml',
  xsl: 'xml',
  yml: 'yaml',
  zsh: 'bash',
}

type Language = keyof typeof GRAMMARS

const EMBEDS: Partial<Record<Language, Language[]>> = {
  erb: ['xml', 'ruby'],
  vue: ['xml', 'javascript', 'typescript', 'css', 'scss'],
}

const loaded = new Map<Language, Promise<void>>()
let engine: Promise<typeof import('highlight.js/lib/core').default> | null = null

function core() {
  engine ??= import('highlight.js/lib/core').then(({ default: hljs }) => hljs)
  return engine
}

function register(name: Language): Promise<void> {
  if (!loaded.has(name)) {
    const embeds = (EMBEDS[name] ?? []).map(register)
    const ready = Promise.all([core(), GRAMMARS[name](), ...embeds])
      .then(([hljs, grammar]) => hljs.registerLanguage(name, grammar.default))
      .catch((error) => {
        loaded.delete(name)
        throw error
      })
    loaded.set(name, ready)
  }

  return loaded.get(name)!
}

function languageOf(block: HTMLElement): Language | undefined {
  const name = block.className.match(/language-(\S+)/)?.[1]
  if (!name) return undefined
  return name in GRAMMARS ? (name as Language) : ALIASES[name]
}

export async function highlight(root: HTMLElement) {
  const blocks = [...root.querySelectorAll<HTMLElement>('pre code[class*="language-"]')]
    .filter((block) => !block.dataset.highlighted)
    .map((block) => ({ block, name: languageOf(block) }))
    .filter((found): found is { block: HTMLElement; name: Language } => found.name !== undefined)
  if (!blocks.length) return

  const hljs = await core().catch(() => undefined)
  if (!hljs) return

  const ready = new Set<Language>()
  await Promise.all(
    [...new Set(blocks.map(({ name }) => name))].map((name) =>
      register(name).then(
        () => ready.add(name),
        () => undefined,
      ),
    ),
  )
  blocks.forEach(({ block, name }) => ready.has(name) && hljs.highlightElement(block))
}
