import type { VariantProps } from 'class-variance-authority'
import { cva } from 'class-variance-authority'

export { default as Badge } from './Badge.vue'

export const badgeVariants = cva(
  'group/badge relative inline-flex w-fit shrink-0 items-center justify-center gap-1 overflow-hidden rounded-sm border px-2.25 text-xs leading-5.5 font-normal whitespace-nowrap antialiased dark:border-none [&>svg]:pointer-events-none [&>svg]:size-3.5! [&>svg]:opacity-60 focus-visible:focus-outline',
  {
    variants: {
      variant: {
        default: 'border-gray-300 bg-gray-50 text-gray-700 dark:bg-gray-800 dark:text-gray-100 [a]:hover:bg-gray-100 [button]:hover:bg-gray-100',
        secondary: 'border-gray-300 bg-white text-gray-700 dark:bg-gray-800 dark:text-gray-300 [a]:hover:bg-gray-100 [button]:hover:bg-gray-100',
        destructive: 'border-red-400 bg-red-50 text-red-700 dark:bg-gray-800 dark:text-red-300 [a]:hover:bg-red-100 [button]:hover:bg-red-100',
        outline: 'border-gray-300 bg-white text-gray-700 dark:bg-gray-800 dark:text-gray-300 [a]:hover:bg-gray-100',
        ghost: 'border-transparent hover:bg-gray-100 dark:hover:bg-gray-800',
        link: 'text-primary underline-offset-4 hover:underline',
      },
    },
    defaultVariants: {
      variant: 'default',
    },
  },
)
export type BadgeVariants = VariantProps<typeof badgeVariants>
