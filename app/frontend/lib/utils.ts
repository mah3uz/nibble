import type { ClassValue } from 'clsx'
import { clsx } from 'clsx'
import { extendTailwindMerge } from 'tailwind-merge'

const twMerge = extendTailwindMerge({
  extend: { theme: { shadow: ['ui-xs', 'ui-sm', 'ui-md', 'ui-lg', 'ui-xl', 'panel'] } },
})

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs))
}

export const humanize = (name: string) => (name.charAt(0).toUpperCase() + name.slice(1)).replaceAll('_', ' ')
