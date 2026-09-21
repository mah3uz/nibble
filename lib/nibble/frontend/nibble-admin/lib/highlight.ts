import { common, createLowlight } from 'lowlight'

type HastNode =
  | { type: 'text'; value: string }
  | { type: 'element'; tagName: string; properties?: { className?: string[] }; children: HastNode[] }

export const lowlight = createLowlight(common)
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
