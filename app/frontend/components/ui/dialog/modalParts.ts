import { Comment, Fragment, type Component, type VNode } from 'vue'

function flatten(nodes: VNode[]): VNode[] {
  return nodes.flatMap((node) =>
    node.type === Fragment && Array.isArray(node.children) ? flatten(node.children as VNode[]) : [node],
  )
}

export function splitFooter(nodes: VNode[] | undefined, footer: Component) {
  const flat = flatten(nodes ?? []).filter((node) => node.type !== Comment)
  return {
    body: flat.filter((node) => node.type !== footer),
    footer: flat.filter((node) => node.type === footer),
  }
}

export const MODAL_OVERLAY_CLASS =
  'data-open:animate-in data-closed:animate-out data-closed:fade-out-0 data-open:fade-in-0 fixed inset-0 bg-gray-800/20 duration-200 dark:bg-gray-950/60'

export const MODAL_FRAME_CLASS =
  'data-open:animate-in data-closed:animate-out data-closed:fade-out-0 data-open:fade-in-0 data-closed:zoom-out-95 data-open:zoom-in-95 fixed top-1/6 left-1/2 flex w-full max-w-[calc(100%-2rem)] -translate-x-1/2 flex-col rounded-2xl bg-white/80 p-2 text-sm shadow-[0_8px_5px_-6px_rgba(0,0,0,0.12),_0_3px_8px_0_rgba(0,0,0,0.02),_0_30px_22px_-22px_rgba(39,39,42,0.35)] backdrop-blur-[2px] duration-200 outline-none sm:max-w-2xl dark:bg-gray-850 dark:shadow-[0_5px_20px_rgba(0,0,0,.5)]'

export const MODAL_CARD_CLASS =
  'relative flex max-h-[60vh] min-h-0 flex-1 flex-col gap-3 overflow-auto rounded-xl border border-gray-400/60 bg-white p-4 text-base text-gray-700 antialiased shadow-[0_1px_16px_-2px_rgba(63,63,71,0.2)] dark:border-none dark:bg-gray-800 dark:text-gray-200 dark:shadow-[0_1px_16px_-2px_rgba(0,0,0,.5)] dark:inset-shadow-2xs dark:inset-shadow-white/10'
