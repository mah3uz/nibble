import type { VariantProps } from 'class-variance-authority'
import { cva } from 'class-variance-authority'

export { default as Button } from './Button.vue'

export const buttonVariants = cva(
  'relative inline-flex shrink-0 cursor-pointer items-center justify-center font-medium whitespace-nowrap no-underline antialiased outline-none select-none focus-visible:focus-outline disabled:cursor-not-allowed disabled:text-gray-400 dark:disabled:text-gray-600 disabled:[&_svg]:opacity-30 aria-invalid:border-destructive [&_svg]:pointer-events-none [&_svg]:shrink-0 [&_svg]:text-gray-925 [&_svg]:opacity-60 dark:[&_svg]:text-white',
  {
    variants: {
      variant: {
        default:
          'from-primary/90 to-primary hover:bg-primary-hover border-primary-border shadow-ui-md border bg-linear-to-b text-white inset-shadow-2xs inset-shadow-white/25 disabled:text-white disabled:opacity-60 disabled:inset-shadow-none dark:disabled:text-white [&_svg]:text-white [&_svg]:opacity-60',
        outline:
          'shadow-ui-sm border border-gray-300 bg-linear-to-b from-white to-gray-50 text-gray-900 hover:bg-gray-50 hover:to-gray-100 dark:border-gray-700/80 dark:from-gray-850 dark:to-gray-900 dark:text-gray-300 dark:shadow-ui-md dark:hover:bg-gray-900 dark:hover:to-gray-850 aria-expanded:to-gray-100',
        secondary:
          'bg-gray-950/5 hover:bg-gray-950/10 hover:text-gray-900 dark:bg-white/4 dark:hover:bg-white/20 dark:hover:text-white [&_svg]:opacity-70',
        ghost:
          'bg-transparent text-gray-900 hover:bg-gray-400/10 dark:text-gray-300 dark:hover:bg-white/7 dark:hover:text-gray-200 aria-expanded:bg-gray-400/10',
        subtle:
          'bg-transparent text-gray-500 hover:bg-gray-400/10 hover:text-gray-700 dark:text-gray-300 dark:hover:bg-white/7 dark:hover:text-gray-200 [&_svg]:opacity-35',
        destructive:
          'border border-red-600 bg-linear-to-b from-red-600/90 to-red-600 text-white inset-shadow-xs inset-shadow-red-300 hover:bg-red-600/90 disabled:text-white! disabled:opacity-60 disabled:inset-shadow-none [&_svg]:text-white [&_svg]:opacity-80',
        link: 'text-primary underline-offset-4 hover:underline',
      },
      size: {
        'default': 'h-10 gap-2 rounded-lg px-4 text-sm [&_svg:not([class*=size-])]:size-4',
        'xs': 'h-6 gap-1.5 rounded-md px-2 text-xs [&_svg:not([class*=size-])]:size-2.5',
        'sm': 'h-8 gap-2 rounded-lg px-3 text-[0.8125rem] leading-tight [&_svg:not([class*=size-])]:size-3',
        'lg': 'h-12 gap-2 rounded-lg px-6 text-base [&_svg:not([class*=size-])]:size-4',
        'icon': 'size-10 gap-0 rounded-lg px-0 [&_svg:not([class*=size-])]:size-4.5 hover:[&_svg]:opacity-70',
        'icon-xs': 'size-6.5 gap-0 rounded-md px-0 [&_svg:not([class*=size-])]:size-3 hover:[&_svg]:opacity-70',
        'icon-sm': 'size-8 gap-0 rounded-lg px-0 [&_svg:not([class*=size-])]:size-3.5 hover:[&_svg]:opacity-70',
        'icon-lg': 'size-12 gap-0 rounded-lg px-0 [&_svg:not([class*=size-])]:size-5 hover:[&_svg]:opacity-70',
      },
    },
    defaultVariants: {
      variant: 'default',
      size: 'default',
    },
  },
)
export type ButtonVariants = VariantProps<typeof buttonVariants>
