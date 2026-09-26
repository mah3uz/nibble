import type { LanguageFn, Mode } from 'highlight.js'
import erb from 'highlight.js/lib/languages/erb'
import { common, createLowlight } from 'lowlight'

type HastNode =
  | { type: 'text'; value: string }
  | { type: 'element'; tagName: string; properties?: { className?: string[] }; children: HastNode[] }

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

export const lowlight = createLowlight({ ...common, erb, vue })
export const codeLanguages = lowlight.listLanguages().sort()

function toDom(node: HastNode): Node {
  if (node.type === 'text') return document.createTextNode(node.value)

  const element = document.createElement(node.tagName)
  element.className = (node.properties?.className ?? []).join(' ')
  node.children.forEach((child) => element.appendChild(toDom(child)))
  return element
}

export function highlightBlocks(root: HTMLElement) {
  root.querySelectorAll<HTMLElement>('pre code[class*="language-"]').forEach((block) => {
    const name = block.className.match(/language-(\S+)/)?.[1]
    if (!name || !lowlight.registered(name)) return

    const tree = lowlight.highlight(name, block.textContent ?? '')
    block.replaceChildren(...(tree.children as HastNode[]).map(toDom))
  })
}
